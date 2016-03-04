defmodule MyApp.Schemas.City do
  @moduledoc false
  use Ecto.Schema

  alias MyApp.Schemas.CityName
  alias MyApp.Schemas.Mayor
  alias MyApp.Schemas.Weather

  schema "city" do
    belongs_to :city_name, CityName
    has_many :weather, Weather
    has_one :mayor, Mayor
    has_many :friends, through: [:mayor, :friends]
    has_many :friend_names, through: [:friends, :friend_name]

    timestamps
  end
end

defmodule MyApp.Schemas.CityName do
  @moduledoc false
  use Ecto.Schema

  alias MyApp.Schemas.City

  schema "city_name" do
    field :name
    has_many :cities, City

    timestamps
  end
end

defmodule MyApp.Schemas.Friend do
  @moduledoc false

  use Ecto.Schema
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

  use Ecto.Schema
  alias MyApp.Schemas.Friend

  schema "friend_name" do
    field :name
    has_many :friends, Friend
  end
end

defmodule MyApp.Schemas.Mayor do
  @moduledoc false

  use Ecto.Schema
  alias MyApp.Schemas.City
  alias MyApp.Schemas.Friend

  schema "mayor" do
    field :name

    belongs_to :city, City
    has_many :friends, Friend
  end
end

defmodule MyApp.Schemas.Weather do
  @moduledoc false
  use Ecto.Schema

  alias MyApp.Schemas.City

  schema "weather" do
    field :temp_lo, :integer
    belongs_to :city, City
  end
end
