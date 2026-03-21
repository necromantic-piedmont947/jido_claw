defmodule JidoClaw.Security.Redaction.LogRedactor do
  @moduledoc false

  alias JidoClaw.Security.Redaction.Patterns

  @spec filter(Logger.message(), Logger.level(), Logger.metadata(), keyword()) ::
          Logger.message() | :stop
  def filter(message, _level, _metadata, _config) do
    case message do
      msg when is_binary(msg) -> Patterns.redact(msg)
      {:string, msg} -> {:string, Patterns.redact(IO.iodata_to_binary(msg))}
      msg when is_list(msg) -> Patterns.redact(IO.iodata_to_binary(msg))
      other -> other
    end
  end
end
