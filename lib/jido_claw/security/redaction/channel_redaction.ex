defmodule JidoClaw.Security.Redaction.ChannelRedaction do
  @moduledoc false

  alias JidoClaw.Security.Redaction.Patterns

  @spec redact_payload(map()) :: map()
  def redact_payload(payload) when is_map(payload) do
    Map.new(payload, fn
      {key, value} when is_binary(value) -> {key, Patterns.redact(value)}
      {key, value} when is_map(value) -> {key, redact_payload(value)}
      {key, value} when is_list(value) -> {key, Enum.map(value, &redact_value/1)}
      pair -> pair
    end)
  end

  defp redact_value(value) when is_binary(value), do: Patterns.redact(value)
  defp redact_value(value) when is_map(value), do: redact_payload(value)
  defp redact_value(other), do: other
end
