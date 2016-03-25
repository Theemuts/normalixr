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

defmodule MyApp.Schemas.CityName do
  @moduledoc false
  #use Normalixr.Schema
  use Normalixr.Schema

  alias MyApp.Schemas.City

  schema "city_name" do
    field :name
    has_many :cities, City

    timestamps
  end
end

defmodule MyApp.Schemas.Friend do
  @moduledoc false

  use Normalixr.Schema
  alias MyApp.Schemas.Mayor
  alias MyApp.Schemas.FriendName

  schema "friend" do
    belongs_to :friend_name, FriendName
    belongs_to :mayor, Mayor

    timestamps
  end
end

defmodule MyApp.Schemas.FriendName do
  @moduledoc false

  use Normalixr.Schema
  alias MyApp.Schemas.Friend

  schema "friend_name" do
    field :name
    has_many :friends, Friend
  end
end

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

defmodule MyApp.Schemas.Pseudonym do
  @moduledoc false

  use Normalixr.Schema

  alias MyApp.Schemas.Mayor

  schema "pseudonym" do
    field :pseudonym

    belongs_to :mayor, Mayor, foreign_key: :another_id, references: :pseudo_id
  end
end

defmodule MyApp.Schemas.Weather do
  @moduledoc false
  use Normalixr.Schema

  alias MyApp.Schemas.City

  schema "weather" do
    field :temp_lo, :integer
    belongs_to :city, City
  end
end

defmodule MyApp.Schemas.Related.Weather do
  @moduledoc false
  use Normalixr.Schema

  schema "related_weather" do
    field :temp_hi, :integer
  end

  def underscored_name, do: :related_weather
end

defmodule MyApp.Schemas.Contact do
  @moduledoc false
  use Normalixr.Schema

  schema "contact" do
    field :name
    field :contact_id

    has_one :associated_contact, __MODULE__, foreign_key: :contact_id
  end
end