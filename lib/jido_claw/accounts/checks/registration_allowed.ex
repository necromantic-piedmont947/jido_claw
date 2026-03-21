defmodule JidoClaw.Accounts.Checks.RegistrationAllowed do
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "registration is allowed"

  @impl true
  def match?(_actor, _context, _opts), do: true
end
