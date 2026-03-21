defmodule JidoClaw.Forge.StepHandler do
  @callback execute(sprite_client :: struct(), args :: map(), opts :: keyword()) ::
              {:ok, map()} | {:needs_input, String.t()} | {:error, term()}
end
