import Config

# Run in CLI mode — skip the Phoenix HTTP server in tests to avoid port conflicts.
config :jido_claw,
  mode: :cli

config :logger,
  level: :warning
