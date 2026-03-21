defmodule JidoClaw.Cron.Persistence do
  @moduledoc """
  YAML persistence for cron job definitions.

  Reads and writes `.jido/cron.yaml` so scheduled jobs survive restarts.
  """

  @filename "cron.yaml"

  @doc "Load all persisted jobs from .jido/cron.yaml"
  @spec load(String.t()) :: {:ok, [map()]} | {:error, term()}
  def load(project_dir) do
    path = yaml_path(project_dir)

    if File.exists?(path) do
      case YamlElixir.read_from_file(path) do
        {:ok, %{"jobs" => jobs}} when is_list(jobs) ->
          {:ok, jobs}

        {:ok, _} ->
          {:ok, []}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, []}
    end
  end

  @doc "Save a list of jobs to .jido/cron.yaml"
  @spec save(String.t(), [map()]) :: :ok | {:error, term()}
  def save(project_dir, jobs) do
    path = yaml_path(project_dir)
    File.mkdir_p!(Path.dirname(path))

    content =
      if jobs == [] do
        "# JidoClaw Cron Jobs\n# Generated automatically. Edit with care.\njobs: []\n"
      else
        header = "# JidoClaw Cron Jobs\n# Generated automatically. Edit with care.\njobs:\n"

        entries =
          Enum.map_join(jobs, "\n", fn job ->
            id = job["id"] || job[:id]
            task = job["task"] || job[:task]
            schedule = job["schedule"] || job[:schedule]
            mode = job["mode"] || job[:mode] || "main"

            """
              - id: "#{id}"
                task: "#{escape_yaml(task)}"
                schedule: "#{escape_yaml(schedule)}"
                mode: #{mode}\
            """
          end)

        header <> entries <> "\n"
      end

    File.write(path, content)
  end

  @doc "Add or update a job in the persistent store (upserts by id)."
  @spec add_job(String.t(), map()) :: :ok | {:error, term()}
  def add_job(project_dir, job) do
    with {:ok, jobs} <- load(project_dir) do
      id = job["id"] || job[:id]
      filtered = Enum.reject(jobs, fn j -> (j["id"] || j[:id]) == id end)

      normalized = %{
        "id" => id,
        "task" => job["task"] || job[:task],
        "schedule" => job["schedule"] || job[:schedule],
        "mode" => to_string(job["mode"] || job[:mode] || "main")
      }

      save(project_dir, filtered ++ [normalized])
    end
  end

  @doc "Remove a job by ID from the persistent store."
  @spec remove_job(String.t(), String.t()) :: :ok | {:error, :not_found}
  def remove_job(project_dir, job_id) do
    with {:ok, jobs} <- load(project_dir) do
      filtered = Enum.reject(jobs, fn j -> (j["id"] || j[:id]) == job_id end)

      if length(filtered) == length(jobs) do
        {:error, :not_found}
      else
        save(project_dir, filtered)
      end
    end
  end

  # -- Private --

  defp yaml_path(project_dir) do
    Path.join([project_dir, ".jido", @filename])
  end

  defp escape_yaml(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  defp escape_yaml(other), do: to_string(other)
end
