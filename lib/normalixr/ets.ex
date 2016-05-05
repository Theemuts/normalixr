defmodule Normalixr.ETS do
  @moduledoc false

  use ExActor.GenServer, export: __MODULE__

  @doc false
  def get(mod) do
    try do
      case :ets.lookup(:normalixr_module_info, mod) do
        [] -> :error
        [{^mod, info}] -> {:ok, info}
      end
    rescue
      ArgumentError -> :error
    end
  end

  @doc false
  def add(mod, info) do
    try do
      :ets.insert(:normalixr_module_info, {mod, info})
    rescue
      ArgumentError -> :error
    end
  end

  defstart start_link do
    initial_state :ets.new(:normalixr_module_info, [:named_table, :set, :public, read_concurrency: true])
  end
end