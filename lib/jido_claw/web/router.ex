defmodule JidoClaw.Web.Router do
  use Phoenix.Router
  import Phoenix.LiveDashboard.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", JidoClaw.Web do
    pipe_through :api

    get "/health", HealthController, :index
    post "/v1/chat/completions", ChatController, :create
  end

  # GitHub webhooks (no auth pipeline — HMAC verified in controller)
  scope "/webhooks", JidoClaw.Web do
    pipe_through :api
    post "/github", WebhookController, :github
  end

  scope "/" do
    pipe_through :browser
    live_dashboard "/dashboard",
      metrics: JidoClaw.Telemetry,
      ecto_repos: []
  end
end
