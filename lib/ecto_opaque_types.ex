defmodule EctoOpaqueTypes do
  @moduledoc """
  Minimal reproduction for the `call_without_opaque` Dialyzer warning
  triggered by `Ecto.Multi` operations on OTP 28.

  Run `mix dialyzer` to reproduce the warning.
  """

  @spec build_multi() :: Ecto.Multi.t()
  def build_multi do
    Ecto.Multi.new()
  end
end
