defmodule MyApp.Schemas.Weather do
  @moduledoc false
  use Normalixr.Schema

  alias MyApp.Schemas.City

  schema "weather" do
    field :temp_lo, :integer
    belongs_to :city, City
  end
end