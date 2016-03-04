defmodule NormalixrTest do
  use ExUnit.Case
  alias MyApp.Models.{CityName, Weather, City, Friend, FriendName, Mayor}
  doctest Normalixr

  test "normalizes without relations" do
    city_model = %City{id: 2}
    assert Normalixr.normalize(city_model) == %{city: %{2 => city_model}}
  end

  test "normalizes belongs_to relations" do
    city_name_model = %CityName{id: 1, name: "Amsterdam"}
    city_model = %City{id: 2, city_name_id: 1, city_name: city_name_model}
    result = Normalixr.normalize(city_model)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].city_name[:field] == :city_name
    assert result.city[2].city_name[:ids] == [1]

    field = result.city[2].city_name.field
    ids = result.city[2].city_name.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
    end
  end

  test "normalizes belongs_to relations when the field is nil" do
    city_model = %City{id: 2, city_name_id: nil, city_name: nil}
    result = Normalixr.normalize(city_model)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].city_name[:field] == :city_name
    assert result.city[2].city_name[:ids] == []

    field = result.city[2].city_name.field
    refute result[field]
  end

  test "normalizes has_one relations" do
    mayor_model = %Mayor{name: "The Mayor", id: 1, city_id: 1}
    city_model = %City{id: 2, mayor: mayor_model}
    result = Normalixr.normalize(city_model)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].mayor[:field] == :mayor
    assert result.city[2].mayor[:ids] == [1]

    field = result.city[2].mayor.field
    ids = result.city[2].mayor.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
    end
  end

  test "normalizes has_one relations when the field is nil" do
    city_model = %City{id: 2, mayor: nil}
    result = Normalixr.normalize(city_model)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].mayor[:field] == :mayor
    assert result.city[2].mayor[:ids] == []

    field = result.city[2].mayor.field

    refute result[field]
  end

  test "normalizes has_many relations" do
    weather_models = [%Weather{id: 1, city_id: 1, temp_lo: 12},
                      %Weather{id: 3, city_id: 1, temp_lo: 10},
                      %Weather{id: 2, city_id: 1, temp_lo: 13}]
    city_model = %City{id: 2, weather: weather_models}
    result = Normalixr.normalize(city_model)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].weather[:field] == :weather
    assert result.city[2].weather[:ids] == [1, 3, 2]

    field = result.city[2].weather.field
    ids = result.city[2].weather.ids

    assert result[field]

    for id <- ids do
      assert result[field][id]
    end
  end

  test "normalizes has_many relations when the field is an empty list" do
    city_model = %City{id: 2, weather: []}
    result = Normalixr.normalize(city_model)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].weather[:field] == :weather
    assert result.city[2].weather[:ids] == []

    field = result.city[2].weather.field
    refute result[field]
  end

  test "normalizes has_many through relations" do
    friends_models = [%Friend{id: 1, mayor_id: 1},
                      %Friend{id: 2, mayor_id: 1},
                      %Friend{id: 3, mayor_id: 1}]
    mayor_model = %Mayor{name: "The Mayor", id: 1, city_id: 1, friends: friends_models}
    city_model = %City{id: 2, city_name_id: 1, mayor: mayor_model, friends: friends_models}
    result = Normalixr.normalize(city_model)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].mayor[:field] == :mayor
    assert result.city[2].friends[:field] == :friend
    assert result.city[2].mayor[:ids] == [1]
    assert result.city[2].friends[:ids] == [1, 2, 3]

    field = result.city[2].mayor.field
    ids = result.city[2].mayor.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
      assert result[field][id].friends
      assert result[field][id].friends[:field] == :friend
      assert result[field][id].friends[:ids] == [1, 2, 3]
    end

    field = result.city[2].friends.field
    ids = result.city[2].friends.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
    end
  end

  test "normalizes many_to_many relations" do
    city_model2 = %City{id: 2}
    city_model1 = %City{id: 1, sister_cities: [city_model2]}
    result = Normalixr.normalize(city_model1)
    assert is_map(result)
    assert result[:city]
    assert result.city[1]
    assert result.city[2]
    assert result.city[1].sister_cities[:field] == :city
    assert result.city[1].sister_cities[:ids] == [2]

    field = result.city[1].sister_cities.field
    ids = result.city[1].sister_cities.ids

    assert result[field]

    for id <- ids do
      assert result[field][id]
    end
  end

  test "normalizes combinations of belongs_to, has_one, has_many, many_to_many, and has_through" do
    city_name_model = %CityName{id: 1, name: "Amsterdam"}

    weather_models = [%Weather{id: 1, city_id: 1, temp_lo: 12},
                      %Weather{id: 3, city_id: 1, temp_lo: 13},
                      %Weather{id: 2, city_id: 1, temp_lo: 10}]

    friends_models = [%Friend{id: 1, mayor_id: 1},
                      %Friend{id: 2, mayor_id: 1},
                      %Friend{id: 3, mayor_id: 1}]

    mayor_model = %Mayor{name: "The Mayor", id: 1, city_id: 1, friends: friends_models}

    sister_city_models = [%City{id: 1}, %City{id: 3}]

    city_model = %City{id: 2, city_name_id: 1, weather: weather_models, city_name: city_name_model, mayor: mayor_model, friends: friends_models, sister_cities: sister_city_models}

    result = Normalixr.normalize(city_model)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].city_name[:field] == :city_name
    assert result.city[2].city_name[:ids] == [1]
    assert result.city[2].weather[:field] == :weather
    assert result.city[2].weather[:ids] == [1, 3, 2]
    assert result.city[2].mayor[:field] == :mayor
    assert result.city[2].mayor[:ids] == [1]
    assert result.city[2].friends[:field] == :friend
    assert result.city[2].friends[:ids] == [1, 2, 3]
    assert result.city[1]
    assert result.city[3]
    assert result.city[2].sister_cities[:field] == :city
    assert result.city[2].sister_cities[:ids] == [1, 3]

    field = result.city[2].city_name.field
    ids = result.city[2].city_name.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
    end

    field = result.city[2].weather.field
    ids = result.city[2].weather.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
    end

    field = result.city[2].mayor.field
    ids = result.city[2].mayor.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
      assert result[field][id].friends
      assert result[field][id].friends[:field] == :friend
      assert result[field][id].friends[:ids] == [1, 2, 3]
    end

    field = result.city[2].friends.field
    ids = result.city[2].friends.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
    end

    field = result.city[2].sister_cities.field
    ids = result.city[2].sister_cities.ids

    assert result[field]

    for id <- ids do
      assert result[field][id]
    end
  end

  test "normalizes deeply-nested models" do
    city_name_model = %CityName{id: 1, name: "Amsterdam"}
    sister_city_models = [%City{id: 1, city_name_id: 1, city_name: city_name_model}]
    city_model = %City{id: 2, sister_cities: sister_city_models}
    result = Normalixr.normalize(city_model)
    assert is_map(result)

    assert result[:city]
    assert result.city[1]
    assert result.city[2]
    assert result.city[2].sister_cities[:field] == :city
    assert result.city[2].sister_cities[:ids] == [1]

    field = result.city[2].sister_cities.field
    ids = result.city[2].sister_cities.ids

    assert result[field]

    for id <- ids do
      assert result[field][id]
    end

    assert result.city[1].city_name[:field] == :city_name
    assert result.city[1].city_name[:ids] == [1]
    assert result[:city_name]

    field = result.city[1].city_name.field
    ids = result.city[1].city_name.ids

    assert result[field]

    for id <- ids do
      assert result[field][id]
    end
  end

  test "normalizes nested has through relations" do
    name_model1 = %FriendName{id: 1, name: "First Name"}
    name_model2 = %FriendName{id: 2, name: "Second Name"}

    friends_models = [%Friend{id: 1, friend_name_id: 1, friend_name: name_model1, mayor_id: 1},
                      %Friend{id: 2, friend_name_id: 1, friend_name: name_model1, mayor_id: 1},
                      %Friend{id: 3, friend_name_id: 2, friend_name: name_model1, mayor_id: 2}]

    mayor_model = %Mayor{name: "The Mayor", id: 1, city_id: 1, friends: friends_models}
    city_model = %City{id: 2, city_name_id: 1, mayor: mayor_model, friends: friends_models, friend_names: [name_model1, name_model2]}
    result = Normalixr.normalize(city_model)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].mayor[:field] == :mayor
    assert result.city[2].friends[:field] == :friend
    assert result.city[2].friend_names[:field] == :friend_name
    assert result.city[2].mayor[:ids] == [1]
    assert result.city[2].friends[:ids] == [1, 2, 3]
    assert result.city[2].friend_names[:ids] == [1, 2]

    field = result.city[2].mayor.field
    ids = result.city[2].mayor.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
      assert result[field][id].friends
      assert result[field][id].friends[:field] == :friend
      assert result[field][id].friends[:ids] == [1, 2, 3]
    end

    field = result.city[2].friends.field
    ids = result.city[2].friends.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
      assert result[field][id].friend_name
      assert result[field][id].friend_name[:field] == :friend_name
      assert result[field][id].friend_name[:ids] in [[1], [2]]
    end

    field = result.city[2].friend_names.field
    ids = result.city[2].friend_names.ids

    assert result[field]
    for id <- ids do
      assert result[field][id]
    end
  end

  test "association ids are merged if the loaded association is different in two models" do
    city_model3 = %City{id: 3}
    city_model1a = %City{id: 1, sister_cities: [city_model3]}
    city_model2 = %City{id: 2, sister_cities: [city_model1a]}
    city_model1b = %City{id: 1, sister_cities: [city_model2]}

    result = Normalixr.normalize(city_model1b)
    assert is_map(result)
    assert result[:city]
    assert result.city[1]
    assert result.city[2]
    assert result.city[1].sister_cities[:field] == :city
    assert result.city[1].sister_cities[:ids] == [3, 2]

    field = result.city[1].sister_cities.field
    ids = result.city[1].sister_cities.ids

    assert result[field]

    for id <- ids do
      assert result[field][id]
    end
  end

  test "nil fields are set if another instance of the model sets them" do
    weather1a = %Weather{id: 1, city_id: 1}
    weather1b = %Weather{id: 1, city_id: 1, temp_lo: 1}

    result = Normalixr.normalize([weather1a])
    assert result == %{weather: %{1 => weather1a}}
    refute result == %{weather: %{1 => weather1b}}

    result = Normalixr.normalize(weather1b, result)
    refute result == %{weather: %{1 => weather1a}}
    assert result == %{weather: %{1 => weather1b}}
  end

  test "fields are not overridden by nil" do
    weather1a = %Weather{id: 1, city_id: 1}
    weather1b = %Weather{id: 1, city_id: 1, temp_lo: 1}

    result = Normalixr.normalize([weather1b])
    assert result == %{weather: %{1 => weather1b}}
    refute result == %{weather: %{1 => weather1a}}

    result = Normalixr.normalize(weather1a, result)
    assert result == %{weather: %{1 => weather1b}}
    refute result == %{weather: %{1 => weather1a}}
  end

  test "raises if fields are not nil and not equal" do
    assert_raise Normalixr.FieldMismatchError, fn ->
      weather1a = %Weather{id: 1, city_id: 1, temp_lo: 2}
      weather1b = %Weather{id: 1, city_id: 1, temp_lo: 1}

      Normalixr.normalize([weather1a, weather1b])
    end
  end

  test "has_one and belongs_to relationship can be backfilled if the data has been loaded" do
    normalized = [%Mayor{name: "The Mayor", id: 2, city_id: 1}, %CityName{id: 1, name: "Here"}, %City{id: 1, city_name_id: 1}]
    |> Normalixr.normalize

    assert Map.fetch(normalized.mayor[2].city, :ids) == :error
    assert Map.fetch(normalized.city[1].mayor, :ids) == :error

    backfilled_city = normalized
    |> Normalixr.backfill([mayor: [:city]])

    assert Map.fetch!(backfilled_city.mayor[2].city, :ids) == [1]
    assert Map.fetch(backfilled_city.city[1].mayor, :ids) == :error

    backfilled_mayor = normalized
    |> Normalixr.backfill([city: [:mayor]])

    assert Map.fetch!(backfilled_mayor.city[1].mayor, :ids) == [2]
    assert Map.fetch(backfilled_mayor.mayor[2].city, :ids) == :error
  end

  test "raises when the association does not exist" do
    assert_raise Normalixr.NonexistentAssociation, fn ->
      %Mayor{name: "The Mayor", id: 2, city_id: 1}
      |> Normalixr.normalize
      |> Normalixr.backfill([mayor: [:does_not_exist]])
    end
  end
end