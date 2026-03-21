defmodule JidoClaw.Shell.SessionManager do
  @moduledoc """
  Manages persistent shell sessions backed by jido_shell with the Host backend.

  Each workspace gets a jido_shell session that:
  - Executes **real host commands** via `JidoClaw.Shell.BackendHost`
  - Preserves CWD across commands (cd persists)
  - Preserves environment variables
  - Tracks command history
  - Streams output via jido_shell's transport model

  The session is created lazily on first use and recreated if it dies.
  """

  use GenServer
  require Logger

  alias Jido.Shell.ShellSession
  alias Jido.Shell.ShellSessionServer

  @default_timeout 30_000
  @max_output_chars 10_000

  defstruct sessions: %{}

  # -- Client API -------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Run a shell command in the session for `workspace_id`.

  Returns `{:ok, %{output: String.t(), exit_code: integer()}}` or `{:error, reason}`.
  """
  @spec run(String.t(), String.t(), non_neg_integer()) ::
          {:ok, %{output: String.t(), exit_code: non_neg_integer()}} | {:error, term()}
  def run(workspace_id, command, timeout \\ @default_timeout) do
    GenServer.call(__MODULE__, {:run, workspace_id, command, timeout}, timeout + 5_000)
  end

  @doc "Return the current working directory for a workspace session."
  @spec cwd(String.t()) :: {:ok, String.t()} | {:error, :no_session}
  def cwd(workspace_id) do
    GenServer.call(__MODULE__, {:cwd, workspace_id})
  end

  @doc "Stop and discard the session for `workspace_id`."
  @spec stop_session(String.t()) :: :ok
  def stop_session(workspace_id) do
    GenServer.call(__MODULE__, {:stop_session, workspace_id})
  end

  # -- Server Callbacks -------------------------------------------------------

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:run, workspace_id, command, timeout}, _from, state) do
    {session_id, new_state} = ensure_session(workspace_id, state)

    result =
      case session_id do
        nil ->
          {:error, "Shell session could not be started"}

        id ->
          execute_command(id, command, timeout)
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:cwd, workspace_id}, _from, state) do
    reply =
      case Map.get(state.sessions, workspace_id) do
        nil ->
          {:error, :no_session}

        session_id ->
          case ShellSessionServer.get_state(session_id) do
            {:ok, session_state} -> {:ok, session_state.cwd}
            {:error, _} -> {:error, :no_session}
          end
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:stop_session, workspace_id}, _from, state) do
    new_sessions =
      case Map.pop(state.sessions, workspace_id) do
        {nil, sessions} ->
          sessions

        {session_id, sessions} ->
          _ = ShellSession.stop(session_id)
          sessions
      end

    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  # Silently ignore stale session events that arrive outside collect loops
  @impl true
  def handle_info({:jido_shell_session, _session_id, _event}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  # -- Private ----------------------------------------------------------------

  defp ensure_session(workspace_id, state) do
    case Map.get(state.sessions, workspace_id) do
      nil ->
        start_new_session(workspace_id, state)

      session_id ->
        case ShellSession.lookup(session_id) do
          {:ok, _pid} ->
            {session_id, state}

          {:error, :not_found} ->
            Logger.debug("[SessionManager] Session #{session_id} gone, recreating")
            new_state = %{state | sessions: Map.delete(state.sessions, workspace_id)}
            start_new_session(workspace_id, new_state)
        end
    end
  end

  defp start_new_session(workspace_id, state) do
    cwd = File.cwd!()

    opts = [
      cwd: cwd,
      backend: {JidoClaw.Shell.BackendHost, %{}}
    ]

    case ShellSession.start(workspace_id, opts) do
      {:ok, session_id} ->
        Logger.debug("[SessionManager] Started host session #{session_id} for #{workspace_id}")
        new_sessions = Map.put(state.sessions, workspace_id, session_id)
        {session_id, %{state | sessions: new_sessions}}

      {:error, reason} ->
        Logger.warning("[SessionManager] Failed to start session: #{inspect(reason)}")
        {nil, state}
    end
  end

  defp execute_command(session_id, command, timeout) do
    case ShellSessionServer.subscribe(session_id, self()) do
      {:ok, :subscribed} -> :ok
      {:error, reason} -> throw({:subscribe_failed, reason})
    end

    drain_events(session_id)

    result =
      case ShellSessionServer.run_command(session_id, command) do
        {:ok, :accepted} ->
          case collect_output(session_id, timeout) do
            {:timeout, _partial} ->
              # Cancel so the session isn't left busy
              _ = ShellSessionServer.cancel(session_id)
              drain_events(session_id)
              {:error, "Command timed out after #{timeout}ms"}

            other ->
              other
          end

        {:error, reason} ->
          {:error, "Command rejected: #{inspect(reason)}"}
      end

    _ = ShellSessionServer.unsubscribe(session_id, self())
    result
  catch
    {:subscribe_failed, reason} ->
      {:error, "Could not subscribe to session: #{inspect(reason)}"}
  end

  defp collect_output(session_id, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_collect(session_id, deadline, [], 0)
  end

  defp do_collect(session_id, deadline, acc, exit_code) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    if remaining <= 0 do
      {:timeout, finalize_output(acc)}
    else
      receive do
        {:jido_shell_session, ^session_id, {:output, chunk}} ->
          do_collect(session_id, deadline, [chunk | acc], exit_code)

        {:jido_shell_session, ^session_id, {:exit_status, code}} ->
          do_collect(session_id, deadline, acc, code)

        {:jido_shell_session, ^session_id, :command_done} ->
          {:ok, %{output: finalize_output(acc), exit_code: exit_code}}

        {:jido_shell_session, ^session_id, {:error, _error}} ->
          {:ok, %{output: finalize_output(acc), exit_code: max(exit_code, 1)}}

        {:jido_shell_session, ^session_id, :command_cancelled} ->
          {:error, "Command was cancelled"}

        {:jido_shell_session, ^session_id, {:command_crashed, reason}} ->
          {:error, "Command crashed: #{inspect(reason)}"}

        # Ignore lifecycle events (command_started, cwd_changed)
        {:jido_shell_session, ^session_id, _other} ->
          do_collect(session_id, deadline, acc, exit_code)
      after
        remaining ->
          {:timeout, finalize_output(acc)}
      end
    end
  end

  defp finalize_output(acc) do
    acc |> Enum.reverse() |> Enum.join() |> truncate_output()
  end

  defp drain_events(session_id) do
    receive do
      {:jido_shell_session, ^session_id, _} -> drain_events(session_id)
    after
      0 -> :ok
    end
  end

  defp truncate_output(output) when byte_size(output) > @max_output_chars do
    String.slice(output, 0, @max_output_chars) <> "\n... (output truncated)"
  end

  defp truncate_output(output), do: output
end
