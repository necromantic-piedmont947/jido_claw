defmodule JidoClaw.Providers.Ollama do
  @moduledoc """
  Ollama provider – self-hosted OpenAI-compatible Chat Completions API.

  Ollama exposes an OpenAI-compatible endpoint at /v1/chat/completions.
  This provider works identically to vLLM — minimal wrapper using defaults.

  ## Configuration

      # Local Ollama (default)
      OLLAMA_API_KEY=ollama  # any non-empty value works for local

      # Ollama Cloud
      OLLAMA_API_KEY=your-cloud-key

  ## Examples

      ReqLLM.generate_text("ollama:qwen3-coder:32b", "Hello!")

      ReqLLM.generate_text("ollama:llama3.3:70b", "Hello!",
        base_url: "https://ollama.com/v1"
      )
  """

  use ReqLLM.Provider,
    id: :ollama,
    default_base_url: "http://localhost:11434/v1",
    default_env_key: "OLLAMA_API_KEY"

  use ReqLLM.Provider.Defaults

  @provider_schema []
end
