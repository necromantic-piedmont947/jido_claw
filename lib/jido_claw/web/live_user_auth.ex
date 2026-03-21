defmodule JidoClaw.Web.LiveUserAuth do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:live_user_optional, _params, session, socket) do
    socket = assign_current_user(socket, session)
    {:cont, socket}
  end

  def on_mount(:live_user_required, _params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, redirect(socket, to: "/dashboard")}
    else
      {:cont, socket}
    end
  end

  defp assign_current_user(socket, session) do
    case session["user_token"] do
      nil ->
        assign(socket, :current_user, nil)

      token ->
        case AshAuthentication.subject_to_user(token, JidoClaw.Accounts.User, JidoClaw.Accounts) do
          {:ok, user} -> assign(socket, :current_user, user)
          _ -> assign(socket, :current_user, nil)
        end
    end
  end
end
