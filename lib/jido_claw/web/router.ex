defmodule JidoClaw.Web.Router do
  use Phoenix.Router
  import Phoenix.LiveDashboard.Router
  import Phoenix.LiveView.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JidoClaw.Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # API routes
  scope "/", JidoClaw.Web do
    pipe_through :api

    get "/health", HealthController, :index
    post "/v1/chat/completions", ChatController, :create
  end

  # GitHub webhooks (HMAC verified in controller)
  scope "/webhooks", JidoClaw.Web do
    pipe_through :api
    post "/github", WebhookController, :github
  end

  # LiveView routes (authenticated)
  scope "/", JidoClaw.Web do
    pipe_through :browser

    live "/", DashboardLive
    live "/dashboard", DashboardLive
    live "/forge", ForgeLive
    live "/workflows", WorkflowsLive
    live "/agents", AgentsLive
    live "/projects", ProjectsLive
    live "/settings", SettingsLive
    live "/folio", FolioLive
    live "/sign-in", SignInLive
    live "/setup", SetupLive
  end

  # Phoenix LiveDashboard (dev only)
  scope "/" do
    pipe_through :browser
    live_dashboard "/live-dashboard",
      metrics: JidoClaw.Telemetry,
      ecto_repos: []
  end
end
