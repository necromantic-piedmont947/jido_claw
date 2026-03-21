defmodule JidoClaw.Forge.Runners.ClaudeCode do
  @behaviour JidoClaw.Forge.Runner
  alias JidoClaw.Forge.{Runner, SpriteClient}
  alias JidoClaw.Security.Redaction.PromptRedaction
  require Logger

  @forge_home "/var/local/forge"

  @impl true
  def init(client, config) do
    prompt = Map.get(config, :prompt, "")
    model = Map.get(config, :model, "claude-sonnet-4-20250514")

    dirs = ["#{@forge_home}/session", "#{@forge_home}/templates", "#{@forge_home}/.claude"]
    for dir <- dirs do
      SpriteClient.exec(client, "mkdir -p #{dir}", [])
    end

    settings = Jason.encode!(%{permissions: %{allow: ["*"]}})
    SpriteClient.write_file(client, "#{@forge_home}/.claude/settings.json", settings)

    if prompt != "" do
      redacted = PromptRedaction.redact(prompt)
      SpriteClient.write_file(client, "#{@forge_home}/session/context.md", redacted)
    end

    {:ok, %{model: model, prompt: prompt, iteration: 0}}
  end

  @impl true
  def run_iteration(client, state, opts) do
    prompt = Keyword.get(opts, :prompt, state.prompt)
    redacted_prompt = PromptRedaction.redact(prompt)
    model = state.model

    command = """
    export HOME=#{@forge_home} && claude -p "#{escape(redacted_prompt)}" \
      --model #{model} \
      --dangerously-skip-permissions \
      --output-format stream-json \
      --max-turns 200
    """

    case SpriteClient.exec(client, command, timeout: 300_000) do
      {output, 0} -> parse_output(output)
      {output, _code} -> {:ok, Runner.error("claude cli failed", output)}
    end
  end

  @impl true
  def apply_input(client, input, _state) do
    SpriteClient.write_file(client, "#{@forge_home}/session/response.json",
      Jason.encode!(%{response: input}))
    :ok
  end

  defp parse_output(output) do
    lines = String.split(output, "\n", trim: true)
    last_result = lines
      |> Enum.filter(&String.starts_with?(&1, "{"))
      |> Enum.reduce(nil, fn line, _acc ->
        case Jason.decode(line) do
          {:ok, %{"type" => "result"} = result} -> result
          _ -> nil
        end
      end)

    case last_result do
      %{"subtype" => "success"} -> {:ok, Runner.done(output)}
      %{"subtype" => "error_max_turns"} -> {:ok, Runner.continue(output)}
      _ -> {:ok, Runner.done(output)}
    end
  end

  defp escape(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("`", "\\`")
    |> String.replace("$", "\\$")
  end
end
