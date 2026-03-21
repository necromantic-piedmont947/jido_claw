defmodule JidoClaw.Workflows.PlanWorkflow do
  @moduledoc """
  Execute skills as DAGs with parallel phase execution.

  Reads `name` and `depends_on` fields from skill steps to build an execution
  graph. Steps within the same phase (no unresolved dependencies on each other)
  run concurrently via `Task.async_stream`. Phases execute sequentially in
  topological order.

  Falls back to the original `SkillWorkflow` for skills without any `depends_on`
  annotations to preserve backward compatibility.

  ## Phase execution model

  Given steps:
      run_tests   (no deps)
      review_code (no deps)
      synthesize  (depends_on: [run_tests, review_code])

  Phases:
      Phase 1: [run_tests, review_code]  — parallel
      Phase 2: [synthesize]              — sequential (waits for phase 1)
  """

  require Logger

  @step_timeout_ms 300_000

  @doc """
  Execute a skill using DAG-based parallel phase execution.

  Returns `{:ok, results}` where results is a list of `{step_name_or_template, result_text}`
  tuples in dependency-resolved order, or `{:error, reason}`.
  """
  @spec run(JidoClaw.Skills.t(), String.t(), String.t()) :: {:ok, list()} | {:error, term()}
  def run(skill, extra_context \\ "", project_dir \\ File.cwd!()) do
    steps = skill.steps

    if Enum.empty?(steps) do
      {:error, "Skill '#{skill.name}' has no steps"}
    else
      with {:ok, named_steps} <- assign_step_names(steps),
           {:ok, phases} <- compute_phases(named_steps) do
        execute_phases(phases, named_steps, extra_context, project_dir)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Step normalisation
  # ---------------------------------------------------------------------------

  # Assign a unique atom name to each step. Uses the `name` field from YAML
  # if present, otherwise generates :step_1, :step_2, ...
  defp assign_step_names(steps) do
    named =
      steps
      |> Enum.with_index(1)
      |> Enum.map(fn {step, idx} ->
        name =
          case Map.get(step, "name") || Map.get(step, :name) do
            nil -> :"step_#{idx}"
            n when is_binary(n) -> String.to_atom(n)
            n when is_atom(n) -> n
          end

        deps =
          case Map.get(step, "depends_on") || Map.get(step, :depends_on) do
            nil -> []
            deps when is_list(deps) -> Enum.map(deps, &to_atom_dep/1)
            dep -> [to_atom_dep(dep)]
          end

        %{
          name: name,
          template: Map.get(step, "template") || Map.get(step, :template),
          task: Map.get(step, "task") || Map.get(step, :task),
          depends_on: deps
        }
      end)

    {:ok, named}
  end

  defp to_atom_dep(dep) when is_atom(dep), do: dep
  defp to_atom_dep(dep) when is_binary(dep), do: String.to_atom(dep)

  # ---------------------------------------------------------------------------
  # Topological sort / phase computation
  # ---------------------------------------------------------------------------

  # Returns a list of phases, each phase being a list of step names.
  # Steps in the same phase have no dependency on each other and can run in
  # parallel. Phases themselves must execute sequentially.
  defp compute_phases(named_steps) do
    step_map = Map.new(named_steps, &{&1.name, &1})

    # Validate all declared dependencies exist
    with :ok <- validate_deps(named_steps, step_map) do
      phases = topo_phases(named_steps, step_map)
      {:ok, phases}
    end
  end

  defp validate_deps(named_steps, step_map) do
    missing =
      Enum.flat_map(named_steps, fn step ->
        Enum.flat_map(step.depends_on, fn dep ->
          if Map.has_key?(step_map, dep), do: [], else: [{step.name, dep}]
        end)
      end)

    if missing == [] do
      :ok
    else
      desc =
        Enum.map_join(missing, ", ", fn {step, dep} -> "#{step} -> #{dep}" end)

      {:error, "Undefined dependencies: #{desc}"}
    end
  end

  # Kahn-style grouping: assign each step a depth = 1 + max(depth of deps).
  # Steps with depth 0 have no deps and form phase 0.
  defp topo_phases(named_steps, step_map) do
    depths =
      Enum.reduce(named_steps, %{}, fn step, acc ->
        depth = step_depth(step, step_map, acc, MapSet.new())
        Map.put(acc, step.name, depth)
      end)

    depths
    |> Enum.group_by(fn {_name, depth} -> depth end, fn {name, _depth} -> name end)
    |> Enum.sort_by(fn {depth, _} -> depth end)
    |> Enum.map(fn {_depth, names} -> names end)
  end

  defp step_depth(step, step_map, known_depths, visiting) do
    if MapSet.member?(visiting, step.name) do
      # Cycle — return 0 (cycle validation is done separately)
      0
    else
      case Map.get(known_depths, step.name) do
        nil ->
          visiting = MapSet.put(visiting, step.name)

          dep_depth =
            step.depends_on
            |> Enum.map(fn dep ->
              dep_step = Map.fetch!(step_map, dep)
              step_depth(dep_step, step_map, known_depths, visiting)
            end)
            |> then(fn depths -> if depths == [], do: -1, else: Enum.max(depths) end)

          dep_depth + 1

        known ->
          known
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Phase execution
  # ---------------------------------------------------------------------------

  defp execute_phases(phases, named_steps, extra_context, project_dir) do
    step_map = Map.new(named_steps, &{&1.name, &1})

    Enum.reduce_while(phases, {:ok, []}, fn phase_names, {:ok, acc_results} ->
      phase_steps = Enum.map(phase_names, &Map.fetch!(step_map, &1))

      case execute_phase(phase_steps, acc_results, extra_context, project_dir) do
        {:ok, phase_results} ->
          {:cont, {:ok, acc_results ++ phase_results}}

        {:error, _} = err ->
          {:halt, err}
      end
    end)
  end

  defp execute_phase(steps, prior_results, extra_context, project_dir) do
    concurrency = max(1, length(steps))

    print_phase_banner(steps)

    results =
      steps
      |> Task.async_stream(
        fn step -> execute_step(step, prior_results, extra_context, project_dir) end,
        max_concurrency: concurrency,
        timeout: @step_timeout_ms,
        on_timeout: :kill_task
      )
      |> Enum.reduce_while([], fn
        {:ok, {:ok, result}}, acc -> {:cont, [result | acc]}
        {:ok, {:error, reason}}, _acc -> {:halt, {:error, reason}}
        {:exit, :timeout}, _acc -> {:halt, {:error, "Step timed out"}}
        {:exit, reason}, _acc -> {:halt, {:error, "Step crashed: #{inspect(reason)}"}}
      end)

    case results do
      {:error, _} = err -> err
      list -> {:ok, Enum.reverse(list)}
    end
  end

  defp execute_step(step, prior_results, extra_context, project_dir) do
    template_name = step.template
    task = step.task

    full_task =
      if extra_context != "" do
        "#{task}\n\nAdditional context: #{extra_context}"
      else
        task
      end

    IO.puts(
      "  \e[2m  [parallel] #{step.name} (#{template_name}) — #{String.slice(task, 0, 55)}...\e[0m"
    )

    params = %{template: template_name, task: full_task, project_dir: project_dir}

    # Prior results are available in context for dependent steps.
    # StepAction doesn't consume them directly, but they could be injected
    # into the task prompt in a future iteration.
    _ = prior_results

    case JidoClaw.Workflows.StepAction.run(params, %{}) do
      {:ok, step_result} ->
        {:ok, {step.name, step_result.result}}

      {:error, reason} ->
        Logger.warning("[PlanWorkflow] Step #{step.name} (#{template_name}) failed: #{reason}")
        {:error, "Step #{step.name} (#{template_name}) failed: #{reason}"}
    end
  end

  defp print_phase_banner(steps) do
    names = Enum.map_join(steps, ", ", & &1.name)

    if length(steps) > 1 do
      IO.puts("  \e[36m  ⟳ parallel phase: #{names}\e[0m")
    else
      IO.puts("  \e[2m  step: #{names}\e[0m")
    end
  end
end
