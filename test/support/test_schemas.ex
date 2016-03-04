defmodule MyApp.Models.City do
  @moduledoc false
  use Ecto.Schema

  alias MyApp.Models.CityName
  alias MyApp.Models.Mayor
  alias MyApp.Models.Weather

  schema "city" do
    belongs_to :city_name, CityName
    has_many :weather, Weather
    has_one :mayor, Mayor
    has_many :friends, through: [:mayor, :friends]
    has_many :friend_names, through: [:friends, :friend_name]
    many_to_many :sister_cities, __MODULE__, join_through: "cities_sister_cities", join_keys: [city_id: :id, sister_city_id: :id]

    timestamps
  end
end

defmodule MyApp.Models.CityName do
  @moduledoc false
  use Ecto.Schema

  alias MyApp.Models.City

  schema "city_name" do
    field :name
    has_many :cities, City

    timestamps
  end
end

defmodule MyApp.Models.Friend do
  @moduledoc false

  use Ecto.Schema
  alias MyApp.Models.Mayor
  alias MyApp.Models.FriendName

  schema "friend" do
    belongs_to :friend_name, FriendName
    belongs_to :mayor, Mayor

    timestamps
  end
end

defmodule MyApp.Models.FriendName do
  @moduledoc false

  use Ecto.Schema
  alias MyApp.Models.Friend

  schema "friend_name" do
    field :name
    has_many :friends, Friend
  end
end

defmodule MyApp.Models.Mayor do
  @moduledoc false

  use Ecto.Schema
  alias MyApp.Models.City
  alias MyApp.Models.Friend

  schema "mayor" do
    field :name

    belongs_to :city, City
    has_many :friends, Friend
  end
end

defmodule MyApp.Models.Weather do
  @moduledoc false
  use Ecto.Schema

  alias MyApp.Models.City

  schema "weather" do
    field :temp_lo, :integer
    belongs_to :city, City
  end
end
