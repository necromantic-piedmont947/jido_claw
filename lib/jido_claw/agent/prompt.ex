defmodule JidoClaw.Agent.Prompt do
  @moduledoc """
  Builds the system prompt for the JIDOCLAW AI coding agent.

  The base prompt lives in `.jido/system_prompt.md` (user-editable). If the file
  doesn't exist, it's created from the bundled default on first boot. Dynamic
  sections (environment, memories, JIDO.md) are appended at runtime.
  """

  # Embed the default system prompt at compile time so the escript/binary is self-contained
  @priv_prompt Path.join([__DIR__, "..", "..", "..", "priv", "defaults", "system_prompt.md"])
  @external_resource @priv_prompt
  @default_system_prompt File.read!(@priv_prompt)

  # ---------------------------------------------------------------------------
  # System prompt file management
  # ---------------------------------------------------------------------------

  @doc """
  Ensure `.jido/system_prompt.md` exists. Writes the default if missing.
  Does NOT overwrite an existing file — user customizations are preserved.
  """
  @spec ensure(String.t()) :: :ok
  def ensure(project_dir) do
    path = system_prompt_path(project_dir)
    dir = Path.dirname(path)

    unless File.exists?(path) do
      File.mkdir_p!(dir)
      File.write!(path, @default_system_prompt)
    end

    :ok
  end

  @doc "Returns the path to the system prompt file for a project."
  def system_prompt_path(project_dir) do
    Path.join([project_dir, ".jido", "system_prompt.md"])
  end

  # ---------------------------------------------------------------------------
  # Dynamic section builders
  # ---------------------------------------------------------------------------

  defp environment_section(cwd, project_type, git_branch, skills, agent_count) do
    skills_list =
      case skills do
        [] -> "  None loaded (place YAML files in .jido/skills/)"
        list -> Enum.map_join(list, "\n", fn s -> "  - #{s.name}: #{s.description}" end)
      end

    """
    ## Environment

    - Working directory: #{cwd}
    - Project type:      #{project_type}
    - Git branch:        #{git_branch}
    - Active agents:     #{agent_count}

    ### Loaded Skills
    #{skills_list}
    """
  end

  defp memories_section([]), do: ""

  defp memories_section(memories) do
    entries =
      Enum.map_join(memories, "\n", fn mem ->
        "- [#{mem.type}] **#{mem.key}**: #{mem.content}"
      end)

    """

    ## Known Context (from persistent memory)
    #{entries}
    """
  end

  defp jido_md_section(nil), do: ""

  defp jido_md_section(content) do
    """

    ## Project Instructions (from JIDO.md)
    #{content}
    """
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Build the full system prompt for the JIDOCLAW agent.

  Reads the base prompt from `.jido/system_prompt.md` (or falls back to the
  compiled default), then appends dynamic sections: environment, memories,
  and JIDO.md content. Called once per session start.
  """
  @spec build(String.t()) :: String.t()
  def build(project_dir) do
    base_prompt = load_base_prompt(project_dir)

    cwd = project_dir
    project_type = detect_type(cwd)
    git_branch = git_branch()
    skills = load_skills(cwd)
    agent_count = load_agent_count()
    memories = load_memories()
    jido_md = load_jido_md(cwd)

    base_prompt <>
      "\n" <>
      environment_section(cwd, project_type, git_branch, skills, agent_count) <>
      memories_section(memories) <>
      jido_md_section(jido_md)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp load_base_prompt(project_dir) do
    path = system_prompt_path(project_dir)

    case File.read(path) do
      {:ok, content} when byte_size(content) > 0 -> content
      _ -> @default_system_prompt
    end
  end

  defp load_skills(_project_dir) do
    JidoClaw.Skills.all()
  rescue
    _ -> []
  catch
    :exit, _ -> []
  end

  defp load_agent_count do
    case Process.whereis(JidoClaw.Jido) do
      nil ->
        0

      _pid ->
        case JidoClaw.Jido.list_agents() do
          {:ok, agents} -> length(agents)
          _ -> 0
        end
    end
  rescue
    _ -> 0
  end

  defp load_memories do
    JidoClaw.Memory.list_recent(20)
  end

  defp load_jido_md(cwd) do
    path = Path.join([cwd, ".jido", "JIDO.md"])

    case File.read(path) do
      {:ok, content} -> content
      _ -> nil
    end
  end

  defp detect_type(dir) do
    cond do
      File.exists?(Path.join(dir, "mix.exs")) -> "Elixir/OTP"
      File.exists?(Path.join(dir, "package.json")) -> "JavaScript/TypeScript"
      File.exists?(Path.join(dir, "Cargo.toml")) -> "Rust"
      File.exists?(Path.join(dir, "go.mod")) -> "Go"
      File.exists?(Path.join(dir, "pyproject.toml")) -> "Python"
      true -> "Unknown"
    end
  end

  defp git_branch do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {b, 0} -> String.trim(b)
      _ -> "not a git repo"
    end
  end
end
