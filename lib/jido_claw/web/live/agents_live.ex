defmodule JidoClaw.Web.AgentsLive do
  use JidoClaw.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Agents")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 style="font-size: 1.5rem; font-weight: 700; margin-bottom: 1.5rem;">Agents</h1>

      <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem;">
        <div class="card">
          <h3 style="font-weight: 600; margin-bottom: 0.5rem;">GitHub Issue Bot</h3>
          <p style="color: var(--muted); font-size: 0.875rem; margin-bottom: 1rem;">
            Automated issue triage, research, and PR generation
          </p>
          <.status_badge status={:ready} />
        </div>

        <div class="card">
          <h3 style="font-weight: 600; margin-bottom: 0.5rem;">Swarm Orchestrator</h3>
          <p style="color: var(--muted); font-size: 0.875rem; margin-bottom: 1rem;">
            Multi-agent task coordination and delegation
          </p>
          <.status_badge status={:ready} />
        </div>

        <div class="card">
          <h3 style="font-weight: 600; margin-bottom: 0.5rem;">Folio Agent</h3>
          <p style="color: var(--muted); font-size: 0.875rem; margin-bottom: 1rem;">
            GTD task management and inbox processing
          </p>
          <.status_badge status={:ready} />
        </div>
      </div>
    </div>
    """
  end
end
