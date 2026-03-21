defmodule JidoClaw.Security.Redaction.Patterns do
  @moduledoc false

  @patterns [
    # OpenAI / generic API keys
    {~r/sk-[a-zA-Z0-9_-]{20,}/, "[REDACTED:API_KEY]"},
    # Anthropic keys
    {~r/sk-ant-[a-zA-Z0-9_-]{20,}/, "[REDACTED:ANTHROPIC_KEY]"},
    # JidoClaw API keys
    {~r/jidoclaw_[a-zA-Z0-9_-]{20,}/, "[REDACTED:JIDOCLAW_KEY]"},
    # GitHub PATs
    {~r/ghp_[a-zA-Z0-9]{36}/, "[REDACTED:GITHUB_PAT]"},
    {~r/github_pat_[a-zA-Z0-9_]{20,}/, "[REDACTED:GITHUB_PAT]"},
    # Bearer tokens
    {~r/Bearer\s+[a-zA-Z0-9_\-\.]{20,}/, "Bearer [REDACTED]"},
    # JWTs (three base64 segments separated by dots)
    {~r/eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/, "[REDACTED:JWT]"},
    # Generic secrets in env vars
    {~r/(?i)(password|secret|token|api_key|apikey)\s*[=:]\s*["']?[^\s"']{8,}["']?/,
     "[REDACTED:SECRET]"},
    # AWS keys
    {~r/AKIA[0-9A-Z]{16}/, "[REDACTED:AWS_KEY]"}
  ]

  @spec redact(String.t()) :: String.t()
  def redact(text) when is_binary(text) do
    Enum.reduce(@patterns, text, fn {pattern, replacement}, acc ->
      Regex.replace(pattern, acc, replacement)
    end)
  end

  def redact(other), do: other
end
