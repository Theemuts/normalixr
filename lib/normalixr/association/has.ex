defmodule Normalixr.Association.Has do
  @moduledoc false

  @type t :: %__MODULE__{
              cardinality: nil | :one | :many,
              field:       atom,
              mod:         atom,
              owner_key:   atom,
              related_key: atom
  }

  defstruct cardinality: nil,
            field:       nil,
            mod:         nil,
            owner_key:   nil,
            related_key: nil
end