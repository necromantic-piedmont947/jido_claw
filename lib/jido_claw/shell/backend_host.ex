defmodule JidoClaw.Shell.BackendHost do
  @moduledoc """
  Host backend for jido_shell that executes real system commands.

  Uses Erlang `Port` for streaming output and real process execution.
  Integrates with jido_shell's session model for CWD/env persistence,
  command history, and the subscribe/transport streaming protocol.

  ## Protocol

  The session server calls `execute/4` which spawns a Task that:
  1. Opens a Port running `sh -c <command>` with the session's CWD and env
  2. Streams `{:command_event, {:output, chunk}}` to `session_pid`
  3. Sends `{:command_finished, {:ok, exit_code}}` on completion
  """

  @behaviour Jido.Shell.Backend

  @default_task_supervisor Jido.Shell.CommandTaskSupervisor
  @max_output_bytes 50_000

  # -- Backend callbacks ------------------------------------------------------

  @impl true
  def init(config) when is_map(config) do
    case Map.fetch(config, :session_pid) do
      {:ok, pid} when is_pid(pid) ->
        {:ok,
         %{
           session_pid: pid,
           task_supervisor: Map.get(config, :task_supervisor, @default_task_supervisor),
           cwd: Map.get(config, :cwd, File.cwd!()),
           env: Map.get(config, :env, %{})
         }}

      _ ->
        {:error, :missing_session_pid}
    end
  end

  @impl true
  def execute(state, command, args, exec_opts) when is_binary(command) and is_list(args) do
    line = command_line(command, args)
    cwd = Keyword.get(exec_opts, :dir, state.cwd)
    env = Keyword.get(exec_opts, :env, state.env)
    timeout = Keyword.get(exec_opts, :timeout, 30_000)
    output_limit = Keyword.get(exec_opts, :output_limit, @max_output_bytes)

    case Task.Supervisor.start_child(state.task_supervisor, fn ->
           run_command(state.session_pid, line, cwd, env, timeout, output_limit)
         end) do
      {:ok, task_pid} ->
        {:ok, task_pid, %{state | cwd: cwd, env: env}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def cancel(_state, command_ref) when is_pid(command_ref) do
    if Process.alive?(command_ref) do
      Process.exit(command_ref, :shutdown)
    end

    :ok
  end

  def cancel(_state, _ref), do: {:error, :invalid_command_ref}

  @impl true
  def terminate(_state), do: :ok

  @impl true
  def cwd(state), do: {:ok, state.cwd, state}

  @impl true
  def cd(state, path) when is_binary(path) do
    # Resolve relative paths against current cwd
    resolved =
      if Path.type(path) == :absolute do
        path
      else
        Path.expand(path, state.cwd)
      end

    if File.dir?(resolved) do
      {:ok, %{state | cwd: resolved}}
    else
      {:error, :not_a_directory}
    end
  end

  # -- Private: command execution ---------------------------------------------

  defp run_command(session_pid, line, cwd, env, timeout, output_limit) do
    # Validate cwd exists
    effective_cwd =
      if File.dir?(cwd) do
        cwd
      else
        File.cwd!()
      end

    port_env =
      Enum.map(env, fn {k, v} ->
        {String.to_charlist(to_string(k)), String.to_charlist(to_string(v))}
      end)

    port =
      Port.open({:spawn, "sh -c #{shell_escape(line)}"}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:cd, effective_cwd},
        {:env, port_env}
      ])

    result = collect_port_output(port, session_pid, timeout, output_limit, 0)
    send(session_pid, {:command_finished, result})
  rescue
    error ->
      send(session_pid, {:command_finished, {:error, Exception.message(error)}})
  end

  defp collect_port_output(port, session_pid, timeout, output_limit, bytes_sent) do
    receive do
      {^port, {:data, chunk}} ->
        new_bytes = bytes_sent + byte_size(chunk)

        if output_limit && new_bytes > output_limit do
          # Send what we have, then truncation notice
          send(session_pid, {:command_event, {:output, chunk}})
          send(session_pid, {:command_event, {:output, "\n... (output truncated)"}})
          # Kill the port and drain
          catch_port_close(port)
          {:ok, :output_truncated}
        else
          send(session_pid, {:command_event, {:output, chunk}})
          collect_port_output(port, session_pid, timeout, output_limit, new_bytes)
        end

      {^port, {:exit_status, exit_code}} ->
        send(session_pid, {:command_event, {:exit_status, exit_code}})
        {:ok, exit_code}
    after
      timeout ->
        catch_port_close(port)
        {:error, "Command timed out after #{timeout}ms"}
    end
  end

  defp catch_port_close(port) do
    try do
      Port.close(port)
    catch
      _, _ -> :ok
    end

    # Drain remaining messages
    receive do
      {^port, _} -> :ok
    after
      100 -> :ok
    end
  end

  defp shell_escape(str) do
    "'" <> String.replace(str, "'", "'\\''") <> "'"
  end

  defp command_line(command, []), do: command
  defp command_line(command, args), do: Enum.join([command | args], " ")
end
