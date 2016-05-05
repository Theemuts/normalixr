defmodule MyApp.Schemas.Related.Weather do
  @moduledoc false
  use Normalixr.Schema

  schema "related_weather" do
    field :temp_hi, :integer
  end

  def underscored_name, do: :related_weather
end