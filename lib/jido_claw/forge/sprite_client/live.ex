defmodule JidoClaw.Forge.SpriteClient.Live do
  @behaviour JidoClaw.Forge.SpriteClient.Behaviour
  require Logger

  defstruct [:sprite_id]

  @impl true
  def create(_spec) do
    Logger.warning("[Forge.SpriteClient.Live] Live sprite client not yet configured — use :fake for dev/test")
    {:error, :not_configured}
  end

  @impl true
  def exec(%__MODULE__{}, _command, _opts), do: {"", 1}

  @impl true
  def spawn(%__MODULE__{}, _command, _args, _opts), do: {:error, :not_configured}

  @impl true
  def write_file(%__MODULE__{}, _path, _content), do: {:error, :not_configured}

  @impl true
  def read_file(%__MODULE__{}, _path), do: {:error, :not_configured}

  @impl true
  def inject_env(%__MODULE__{}, _env), do: {:error, :not_configured}

  @impl true
  def destroy(%__MODULE__{}, _sprite_id), do: :ok

  @impl true
  def impl_module, do: __MODULE__
end
