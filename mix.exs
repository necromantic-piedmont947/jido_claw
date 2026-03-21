defmodule JidoClaw.MixProject do
  use Mix.Project

  @version "0.3.0"

  def project do
    [
      app: :jido_claw,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      compilers: Mix.compilers(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {JidoClaw.Application, []},
      # Nostrum is started conditionally — see channel_children() in application.ex
    ]
  end

  defp escript do
    [
      main_module: JidoClaw.CLI.Main,
      name: "jidoclaw",
      embed_elixir: true
    ]
  end

  defp deps do
    [
      # Jido framework (agent engine) — overrides for cross-repo compatibility
      {:jido, "~> 2.1", override: true},
      {:jido_ai, "~> 2.0", override: true},
      {:jido_action, "~> 2.0", override: true},
      {:req_llm, "~> 1.6"},

      # Jido ecosystem — full stack
      {:jido_signal, "~> 2.0", override: true},
      {:jido_mcp, github: "agentjido/jido_mcp", branch: "main"},
      {:jido_memory, github: "agentjido/jido_memory", branch: "main"},
      {:jido_browser, "~> 0.8"},
      {:jido_skill, github: "agentjido/jido_skill", branch: "main"},
      {:jido_composer, "~> 0.3"},
      {:jido_messaging, github: "agentjido/jido_messaging", branch: "main"},
      {:jido_shell, github: "agentjido/jido_shell", branch: "main"},
      {:jido_vfs, github: "agentjido/jido_vfs", branch: "main"},

      # Data
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.12"},

      # Phoenix gateway
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:bandit, "~> 1.5"},
      {:phoenix_pubsub, "~> 2.1"},

      # Telemetry
      {:telemetry, "~> 1.2", override: true},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},

      # Scheduling
      {:crontab, "~> 1.1"},

      # Clustering
      {:libcluster, "~> 3.4"},

      # HTTP client
      {:finch, "~> 0.19"},

      # Discord (optional — only starts when DISCORD_BOT_TOKEN is set).
      # Excluded from the test env entirely: nostrum crashes at startup without a
      # valid token and the Discord adapter guards calls with Code.ensure_loaded/1.
      {:nostrum, "~> 0.10", optional: true, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
