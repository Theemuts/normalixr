defmodule MyApp.Schemas.City do
  @moduledoc false
  use Normalixr.Schema

  alias MyApp.Schemas.CityName
  alias MyApp.Schemas.Mayor
  alias MyApp.Schemas.Weather

  schema "city" do
    belongs_to :city_name, CityName
    has_many :weather, Weather
    has_one :mayor, Mayor
    has_one :mayor_pseudonym, through: [:mayor, :pseudonym]
    has_many :friends, through: [:mayor, :friends]
    has_many :friend_names, through: [:friends, :friend_name]
    many_to_many :sister_cities, __MODULE__, join_through: "cities_sister_cities", join_keys: [city_id: :id, sister_city_id: :id]

    timestamps
  end
end
