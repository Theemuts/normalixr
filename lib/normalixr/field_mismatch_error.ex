defmodule Normalixr.FieldMismatchError do
  @moduledoc false
  defexception message: "The fields in two instances of the same model don't match."
end

defmodule Normalixr.NonexistentAssociation do
  @moduledoc false
  defexception message: "The association does not exist."
end