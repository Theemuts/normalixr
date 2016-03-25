defmodule Normalixr.Association.HasThrough do
  @moduledoc false

  @type t :: %__MODULE__{
              cardinality: nil | :one | :many,
              field:       atom,
              through:     [] | [atom],
              mods:         Keyword.t
  }

  defstruct cardinality: nil,
            field:       nil,
            through:     [],
            mods:        []
end