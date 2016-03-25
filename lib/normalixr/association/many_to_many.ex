defmodule Normalixr.Association.ManyToMany do
  @moduledoc false

  @type t :: %__MODULE__{
              field: atom,
              mod:   atom
  }

  defstruct field: nil,
            mod:   nil
end