defmodule Normalixr.PhoenixView.Test do
  use ExUnit.Case
  alias MyApp.Schemas.City

  doctest Normalixr.PhoenixView

  test "calls default render function in passed view module" do
    city_schema = %City{id: 2}
    normalized = Normalixr.normalize(city_schema)

    opts = [data: normalized,
            fields_to_render: [city: [view: MyApp.CityView]]]

    assert Normalixr.PhoenixView.render("normalized.json", opts) === %{data: %{city: %{2 => %{id: 2}}}}
  end

  test "rendered template can be changed" do
    city_schema = %City{id: 2}
    normalized = Normalixr.normalize(city_schema)

    opts = [data: normalized,
            fields_to_render: [city: [view: MyApp.CityView, template: "new_city.json"]]]

    assert Normalixr.PhoenixView.render("normalized.json", opts) === %{data: %{city: %{2 => %{id: 12}}}}
  end

  test "models aren't rendered if only returns false" do
    city_schemas = [%City{id: 1}, %City{id: 2}]
    normalized = Normalixr.normalize(city_schemas)

    only = fn({_, model}, _) -> model.id == 1 end

    opts = [data: normalized,
            fields_to_render: [city: [view: MyApp.CityView, only: only]]]

    assert Normalixr.PhoenixView.render("normalized.json", opts) == %{data: %{city: %{1 => %{id: 1}}}}
  end

  test "models aren't rendered if except returns true" do
    city_schemas = [%City{id: 1}, %City{id: 2}]
    normalized = Normalixr.normalize(city_schemas)

    except = fn({_, model}, _) -> model.id == 2 end

    opts = [data: normalized,
            fields_to_render: [city: [view: MyApp.CityView, except: except]]]

    assert Normalixr.PhoenixView.render("normalized.json", opts) == %{data: %{city: %{1 => %{id: 1}}}}
  end

  test "Field is skipped by default if no data is present" do
    opts = [data: %{},
            fields_to_render: [city: [view: MyApp.CityView]]]

    assert Normalixr.PhoenixView.render("normalized.json", opts) === %{data: %{}}
  end

  test "Field is not skipped if dont_render_if_empty is set to false and there is no data" do
    opts = [data: %{},
            fields_to_render: [city: [view: MyApp.CityView, dont_render_if_empty: false]]]

    assert Normalixr.PhoenixView.render("normalized.json", opts) === %{data: %{city: %{}
  end

  test "NoDataError is raised if raise_if_no_results is set to true and there is no data" do
    opts = [data: %{},
            fields_to_render: [city: [view: MyApp.CityView, raise_if_no_results: true]]]

    assert_raise Normalixr.NoDataError, fn ->
      Normalixr.PhoenixView.render("normalized.json", opts)
    end
  end
end