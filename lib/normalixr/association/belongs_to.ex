defmodule Normalixr.Association.BelongsTo do
  @moduledoc false

  @type t :: %__MODULE__{
              field:       atom,
              mod:         atom,
              owner_key:   atom,
              related_key: atom
  }

  defstruct field:       nil,
            mod:         nil,
            owner_key:   nil,
            related_key: nil
end