defmodule Normalixr.Schema do
  @moduledoc """
  This module must be used in every Ecto schema which is passed to
  `Normalixr.normalize\2`. After replacing `use Ecto.Schema` with
  `use Normalixr.Schema, mod: __MODULE__`, two new functions are available in the module. The
  first is `underscored_name/0`, which can be overridden and returns the name
  that is used in the normalized representation.

  The second is `normalixr_assocs/0`, which returns the associations of the
  schema used to normalize and backfill schemas.
  """
  defmacro __using__(_) do
    name =
      __CALLER__.module
      |> Module.split
      |> List.last
      |> Macro.underscore
      |> String.to_atom

    quote do
      use Ecto.Schema

      def underscored_name, do: unquote(name)
      def normalixr_assocs, do: Normalixr.ModuleInfo.extract_assocs(__MODULE__)

      defoverridable [underscored_name: 0]
    end
  end
end