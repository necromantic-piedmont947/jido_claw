defmodule JidoClaw.Security.Redaction.PromptRedaction do
  @moduledoc false

  alias JidoClaw.Security.Redaction.Patterns

  @spec redact(String.t() | list()) :: String.t() | list()
  def redact(text) when is_binary(text), do: Patterns.redact(text)

  def redact(messages) when is_list(messages) do
    Enum.map(messages, fn
      %{"content" => content} = msg when is_binary(content) ->
        Map.put(msg, "content", Patterns.redact(content))

      %{content: content} = msg when is_binary(content) ->
        Map.put(msg, :content, Patterns.redact(content))

      other ->
        other
    end)
  end

  def redact(other), do: other
end
