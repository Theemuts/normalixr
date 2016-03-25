defmodule MyApp.CityView do
  @moduledoc false

  def render("city.json", [city: city, normalized_data: _normalized_data]) do
    %{id: city.id}
  end

  def render("new_city.json", [city: city, normalized_data: _normalized_data]) do
    %{id: city.id + 10}
  end
end