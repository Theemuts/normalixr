defmodule NormalixrTest do
  use ExUnit.Case
  alias MyApp.Schemas.{CityName, Weather, City, Friend, FriendName, Mayor, Pseudonym, Contact}

  doctest Normalixr

  test "normalizes without relations" do
    city_schema = %City{id: 2}
    assert Normalixr.normalize(city_schema) == %{city: %{2 => city_schema}}
  end

  test "normalizes belongs_to relations" do
    city_name_schema = %CityName{id: 1, name: "Amsterdam"}
    city_schema = %City{id: 2, city_name_id: 1, city_name: city_name_schema}
    result = Normalixr.normalize(city_schema)
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
    city_schema = %City{id: 2, city_name_id: nil, city_name: nil}
    result = Normalixr.normalize(city_schema)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].city_name[:field] == :city_name
    assert result.city[2].city_name[:ids] == []

    field = result.city[2].city_name.field
    refute result[field]
  end

  test "normalizes has_one relations" do
    mayor_schema = %Mayor{name: "The Mayor", id: 1, city_id: 1}
    city_schema = %City{id: 2, mayor: mayor_schema}
    result = Normalixr.normalize(city_schema)
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
    city_schema = %City{id: 2, mayor: nil}
    result = Normalixr.normalize(city_schema)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].mayor[:field] == :mayor
    assert result.city[2].mayor[:ids] == []

    field = result.city[2].mayor.field

    refute result[field]
  end

  test "normalizes has_many relations" do
    weather_schemas = [%Weather{id: 1, city_id: 1, temp_lo: 12},
                      %Weather{id: 3, city_id: 1, temp_lo: 10},
                      %Weather{id: 2, city_id: 1, temp_lo: 13}]
    city_schema = %City{id: 2, weather: weather_schemas}
    result = Normalixr.normalize(city_schema)
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
    city_schema = %City{id: 2, weather: []}
    result = Normalixr.normalize(city_schema)
    assert is_map(result)
    assert result[:city]
    assert result.city[2]
    assert result.city[2].weather[:field] == :weather
    assert result.city[2].weather[:ids] == []

    field = result.city[2].weather.field
    refute result[field]
  end

  test "normalizes has_many through relations" do
    friends_schemas = [%Friend{id: 1, mayor_id: 1},
                      %Friend{id: 2, mayor_id: 1},
                      %Friend{id: 3, mayor_id: 1}]
    mayor_schema = %Mayor{name: "The Mayor", id: 1, city_id: 1, friends: friends_schemas}
    city_schema = %City{id: 2, city_name_id: 1, mayor: mayor_schema, friends: friends_schemas}
    result = Normalixr.normalize(city_schema)
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
    city_schema2 = %City{id: 2}
    city_schema1 = %City{id: 1, sister_cities: [city_schema2]}
    result = Normalixr.normalize(city_schema1)
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
    city_name_schema = %CityName{id: 1, name: "Amsterdam"}

    weather_schemas = [%Weather{id: 1, city_id: 1, temp_lo: 12},
                      %Weather{id: 3, city_id: 1, temp_lo: 13},
                      %Weather{id: 2, city_id: 1, temp_lo: 10}]

    friends_schemas = [%Friend{id: 1, mayor_id: 1},
                      %Friend{id: 2, mayor_id: 1},
                      %Friend{id: 3, mayor_id: 1}]

    mayor_schema = %Mayor{name: "The Mayor", id: 1, city_id: 1, friends: friends_schemas}

    sister_city_schemas = [%City{id: 1}, %City{id: 3}]

    city_schema = %City{id: 2, city_name_id: 1, weather: weather_schemas, city_name: city_name_schema, mayor: mayor_schema, friends: friends_schemas, sister_cities: sister_city_schemas}

    result = Normalixr.normalize(city_schema)
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

  test "normalizes deeply-nested schemas" do
    city_name_schema = %CityName{id: 1, name: "Amsterdam"}
    sister_city_schemas = [%City{id: 1, city_name_id: 1, city_name: city_name_schema}]
    city_schema = %City{id: 2, sister_cities: sister_city_schemas}
    result = Normalixr.normalize(city_schema)
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
    name_schema1 = %FriendName{id: 1, name: "First Name"}
    name_schema2 = %FriendName{id: 2, name: "Second Name"}

    friends_schemas = [%Friend{id: 1, friend_name_id: 1, friend_name: name_schema1, mayor_id: 1},
                      %Friend{id: 2, friend_name_id: 1, friend_name: name_schema1, mayor_id: 1},
                      %Friend{id: 3, friend_name_id: 2, friend_name: name_schema1, mayor_id: 2}]

    mayor_schema = %Mayor{name: "The Mayor", id: 1, city_id: 1, friends: friends_schemas}
    city_schema = %City{id: 2, city_name_id: 1, mayor: mayor_schema, friends: friends_schemas, friend_names: [name_schema1, name_schema2]}
    result = Normalixr.normalize(city_schema)
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

  test "association ids are merged if the loaded association is different in two schemas" do
    city_schema3 = %City{id: 3}
    city_schema1a = %City{id: 1, sister_cities: [city_schema3]}
    city_schema2 = %City{id: 2, sister_cities: [city_schema1a]}
    city_schema1b = %City{id: 1, sister_cities: [city_schema2]}

    result = Normalixr.normalize(city_schema1b)
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

  test "nil fields are set if another instance of the schema sets them" do
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

  test "has_one, has_one through, and belongs_to relationships can be backfilled if the data has been loaded" do
    backfilled = [%Mayor{name: "The Mayor", id: 2, city_id: 1, pseudo_id: 3},
                  %Pseudonym{pseudonym: "Mr. Mayor", id: 1, another_id: 3},
                  %CityName{id: 1, name: "Here"},
                  %City{id: 1, city_name_id: 1}]
    |> Normalixr.normalize
    |> Normalixr.backfill([mayor: [:pseudonym, :city], city: [:mayor, :mayor_pseudonym]])

    assert Map.fetch!(backfilled.city[1].mayor, :ids) == [2]
    assert Map.fetch!(backfilled.city[1].mayor_pseudonym, :ids) == [1]
    assert %Ecto.Association.NotLoaded{} = backfilled.city[1].city_name
    assert Map.fetch!(backfilled.mayor[2].city, :ids) == [1]
  end

  test "raises if many_to_many / has_many / has_many through fields are backfilled" do
    assert_raise Normalixr.UnspportedAssociation, fn ->
      %City{id: 1, city_name_id: 1}
      |> Normalixr.normalize
      |> Normalixr.backfill([city: [:weather]])
    end

    assert_raise Normalixr.UnspportedAssociation, fn ->
      %City{id: 1, city_name_id: 1}
      |> Normalixr.normalize
      |> Normalixr.backfill([city: [:sister_cities]])
    end

    assert_raise Normalixr.UnspportedAssociation, fn ->
      %City{id: 1, city_name_id: 1}
      |> Normalixr.normalize
      |> Normalixr.backfill([city: [:friends]])
    end
  end

  test "raises when the association does not exist" do
    assert_raise Normalixr.NonexistentAssociation, fn ->
      %Mayor{name: "The Mayor", id: 2, city_id: 1}
      |> Normalixr.normalize
      |> Normalixr.backfill([mayor: [:does_not_exist]])
    end
  end

  test "backfills self-related models" do
    backfilled = [%Contact{id: 1, contact_id: 2, name: "a"}, %Contact{id: 2, contact_id: 1, name: "a"}]
    |> Normalixr.normalize
    |> Normalixr.backfill(contact: [:associated_contact])

    assert backfilled.contact[1].associated_contact.ids == [2]
    assert backfilled.contact[2].associated_contact.ids == [1]
  end
end