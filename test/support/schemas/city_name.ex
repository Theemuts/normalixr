defmodule MyApp.Schemas.CityName do
  @moduledoc false
  use Normalixr.Schema

  alias MyApp.Schemas.City

  schema "city_name" do
    field :name
    has_many :cities, City

    timestamps
  end
end
