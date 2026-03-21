defmodule JidoClaw.Forge.Bootstrap do
  require Logger

  @spec execute(struct(), list(map()), keyword()) :: :ok | {:error, map(), term()}
  def execute(client, steps, opts \\ []) do
    on_step = Keyword.get(opts, :on_step)
    sprite_client = JidoClaw.Forge.SpriteClient

    steps
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {step, index}, :ok ->
      if on_step, do: on_step.(step, index)

      case execute_step(sprite_client, client, step) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, step, reason}}
      end
    end)
  end

  defp execute_step(sprite_client, client, %{"type" => "exec", "command" => command}) do
    case sprite_client.exec(client, command, []) do
      {_output, 0} -> :ok
      {output, code} -> {:error, "command exited with #{code}: #{String.slice(output, 0, 500)}"}
    end
  end

  defp execute_step(sprite_client, client, %{"type" => "file", "path" => path, "content" => content}) do
    sprite_client.write_file(client, path, content)
  end

  defp execute_step(_sprite_client, _client, step) do
    {:error, {:unknown_step_type, step}}
  end
end
