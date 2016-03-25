defmodule Normalixr.Util do
  @moduledoc false

  @doc """
  A wrapper around a call to Enum.filter_map/3 piped into Enum.into/2.
  """
  def filter_map_into(enumerable, filter, mapper, into \\ %{}) do
    Enum.filter_map(enumerable, filter, mapper)
    |> Enum.into(into)
  end
end