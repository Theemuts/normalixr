defmodule MyApp.Schemas.Mayor do
  @moduledoc false

  use Normalixr.Schema
  alias MyApp.Schemas.City
  alias MyApp.Schemas.Friend
  alias MyApp.Schemas.Pseudonym

  schema "mayor" do
    field :name
    field :pseudo_id

    has_one :pseudonym, Pseudonym, foreign_key: :another_id, references: :pseudo_id
    belongs_to :city, City
    has_many :friends, Friend
  end
end