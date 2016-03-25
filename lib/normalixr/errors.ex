defmodule Normalixr.FieldMismatchError do
  @moduledoc false
  defexception message: "The fields in two instances of the same schema don't match."
end

defmodule Normalixr.NonexistentAssociation do
  @moduledoc false
  defexception message: "The association does not exist."
end

defmodule Normalixr.NoDataError do
  @moduledoc false
  defexception message: "There is no data to be rendered, but the field has been marked as required."
end

defmodule Normalixr.UnspportedAssociation do
  @moduledoc false
  defexception message: "The association cannot be backfilled, because it is not a has_one, has_one through, or belongs_to relationship."
end

defmodule Normalixr.TooManyResultsError do
  @moduledoc false
  defexception message: "The association could not be backfilled, because more than one assocatiad schema was found."
end