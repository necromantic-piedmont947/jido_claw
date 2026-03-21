defmodule JidoClaw.Workflows.StepAction do
  @moduledoc """
  A Jido.Action that executes a single skill step by spawning an agent
  from a template, running a task via ask_sync, and returning the result.

  Used as a node in jido_composer Workflows to replace the hand-rolled
  sequential agent spawning in RunSkill.
  """

  use Jido.Action,
    name: "skill_step",
    description: "Execute a skill step by spawning a templated agent and running a task",
    schema: [
      template: [type: :string, required: true, doc: "Agent template name (e.g. coder, reviewer)"],
      task: [type: :string, required: true, doc: "Task prompt for the agent"],
      project_dir: [type: :string, required: false, doc: "Project directory for tool context"]
    ]

  require Logger

  @impl true
  def run(params, _context) do
    template_name = params.template
    task = params.task
    project_dir = Map.get(params, :project_dir, File.cwd!())

    with {:ok, template} <- JidoClaw.Agent.Templates.get(template_name),
         tag = "wf_#{template_name}_#{:erlang.unique_integer([:positive])}",
         {:ok, pid} <- JidoClaw.Jido.start_agent(template.module, id: tag) do
      try do
        case template.module.ask_sync(pid, task,
               timeout: 180_000,
               tool_context: %{project_dir: project_dir}
             ) do
          {:ok, result} -> {:ok, %{template: template_name, result: extract_result(result)}}
          {:error, reason} -> {:error, "Step #{template_name} failed: #{inspect(reason)}"}
          other -> {:ok, %{template: template_name, result: inspect(other)}}
        end
      rescue
        e -> {:error, "Step #{template_name} crashed: #{Exception.message(e)}"}
      after
        if Process.alive?(pid), do: Process.exit(pid, :normal)
      end
    else
      {:error, reason} -> {:error, "Step #{template_name} setup failed: #{inspect(reason)}"}
    end
  end

  defp extract_result(%{last_answer: answer}) when is_binary(answer), do: answer
  defp extract_result(%{answer: answer}) when is_binary(answer), do: answer
  defp extract_result(%{text: text}) when is_binary(text), do: text
  defp extract_result(result) when is_binary(result), do: result
  defp extract_result(result), do: inspect(result, limit: :infinity, pretty: true)
end
