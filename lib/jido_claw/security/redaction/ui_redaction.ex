defmodule JidoClaw.Security.Redaction.UiRedaction do
  @moduledoc false

  alias JidoClaw.Security.Redaction.Patterns

  @spec redact(String.t()) :: String.t()
  def redact(text) when is_binary(text), do: Patterns.redact(text)
  def redact(other), do: other
end
