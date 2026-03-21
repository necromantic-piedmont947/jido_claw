defmodule JidoClaw.Session.Supervisor do
  @moduledoc "Manages session worker processes."

  def start_session(tenant_id, session_id) do
    # Try tenant-specific supervisor first, fall back to global
    sup = JidoClaw.Tenant.InstanceSupervisor.session_sup(tenant_id)

    child_spec = {
      JidoClaw.Session.Worker,
      tenant_id: tenant_id, session_id: session_id
    }

    case GenServer.whereis(sup) do
      nil ->
        # Tenant supervisor not started, use global fallback
        DynamicSupervisor.start_child(JidoClaw.SessionSupervisor, child_spec)

      _pid ->
        DynamicSupervisor.start_child(sup, child_spec)
    end
  end

  def ensure_session(tenant_id, session_id) do
    name = {:via, Registry, {JidoClaw.SessionRegistry, {tenant_id, session_id}}}

    case GenServer.whereis(name) do
      nil -> start_session(tenant_id, session_id)
      pid -> {:ok, pid}
    end
  end

  def list_sessions(tenant_id) do
    Registry.select(JidoClaw.SessionRegistry, [
      {{{:"$1", :"$2"}, :"$3", :_}, [{:==, :"$1", tenant_id}], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Enum.map(fn {_tid, sid, pid} -> {sid, pid} end)
  end
end
