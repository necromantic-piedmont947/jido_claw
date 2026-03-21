defmodule JidoClaw.Accounts.User.Senders.SendMagicLinkEmail do
  use AshAuthentication.Sender

  @impl true
  def send(_user, _token, _opts) do
    # TODO: implement email sending
    :ok
  end
end
