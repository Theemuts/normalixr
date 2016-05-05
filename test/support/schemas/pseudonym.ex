defmodule MyApp.Schemas.Pseudonym do
  @moduledoc false

  use Normalixr.Schema

  alias MyApp.Schemas.Mayor

  schema "pseudonym" do
    field :pseudonym

    belongs_to :mayor, Mayor, foreign_key: :another_id, references: :pseudo_id
  end
end