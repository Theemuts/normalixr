defmodule Normalixr.Schema do
  @moduledoc """
  This module must be used in every Ecto schema which is passed to
  `Normalixr.normalize/2`. After replacing `use Ecto.Schema` with
  `use Normalixr.Schema`, a new function is available in the module:
  `underscored_name/0`, which can be overridden and returns the name that is
  used in the normalized representation.
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
      defoverridable [underscored_name: 0]
    end
  end
end