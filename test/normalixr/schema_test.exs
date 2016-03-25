defmodule Normalixr.Schema.Test do
  use ExUnit.Case
  alias MyApp.Schemas.Related.Weather

  test "underscored_name/0 can be overridden" do
    assert Weather.underscored_name === :related_weather
  end
end