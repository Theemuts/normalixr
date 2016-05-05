A small project that allows you to normalize Ecto schemas. This version supports the release candidate of Ecto 2.

## Installation

The package can be installed as follows:

  1. Add Normalixr to your list of dependencies in `mix.exs`:

        ```
        def deps do
          [{:normalixr, "~> 0.4.0"}]
        end
        ```

  2. Add Normalixr to your list of applications in `mix.exs`:

        ```
        def application do
          [applications: [:logger, :normalixr]]
        end
        ```

  3. Replace every instance of `use Ecto.Schema` with `use Normalixr.Schema`

## Documentation

### Normalization

The major function in this application is `Normalixr.normalize/2`. The first
argument is an `Ecto` schema or a list thereof. The second argument is optional
and can be ignored in most use cases, it is the result of a previous call to
this function, and serves as an accumulator.

This means you can simply normalize the result of a query as follows:

  ```
  normalized = query
  |> Repo.all
  |> Normalixr.normalize
  ```

This function removes all nesting from the result, and transforms it to a
flat representation.

In this flat representation, every schema is added to a field whose name is
derived from the schema name. By default, it uses the underscored
version of the final block of the schema name. For example,
schemas belonging to `MyApp.Weather` will be added to the field `:weather`,
and `MyApp.CityName` to `:city_name`.

(N.B. This means that `MyApp.API` will be converted to `:a_p_i`, so
you can override the default behaviour by defining
`def underscored_name, do: :api` in `MyApp.API`.)

These fields are maps, and the key of a particular schema is equal to its
primary key. For example, a schema with the primary key field equal to 1
belonging to `MyApp.Weather` is normalized to:

  ```
  %{weather: %{1 => %MyApp.Weather{id: 1}}
  ```

Any nesting due to preloading schemas is removed by this function as well.
If the field `:cities` has been preloaded and this schema is called
`MyApp.City`, the field will be replaced with a map:

  ```
  %MyApp.Weather{id: 1, cities: [%MyApp.City{id: 1}, %MyApp.City{id: 2}]}
  ```

is normalized to

  ```
  %{weather:
    %{1 => %MyApp.Weather{id: 1,
                          cities: %{field: :city,
                                    ids:   [1, 2]}}},
    %{city:
      %{1 => %MyApp.City{id: 1},
        2 => %MyApp.City{id: 2}}
    }
  ```

This behaviour is cardinality-independent. If the schema is on the one-end of
the relationship, the ids-field will contain a single-element list.

### Rendering

In order to facilitate integration with Phoenix, Normalixr offers the
`Normalixr.PhoenixView`-module. In a Phoenix controller (or any other module
which imports the `render`-functions from `Phoenix.Controller`), you can call:

  ```
  data = query
  |> Repo.all
  |> Normalixr.normalize

  assigns = %{data: data,
             fields_to_render: [city: [view: MyApp.CityView],
                               [weather: [view: MyApp.WeatherView]]]}
  render(conn, Normalixr.PhoenixView, "normalized.json", assigns)
  ```

This will render the `"city.json"`-template in `MyApp.CityView` and the
`"weather.json"`-template in `MyApp.WeatherView`. These templates will receive
a two-parameter map as data, specifically, it will always have the key
`:normalized_data`, which points to the full normalized representation, the
second points to the schema being rendered, and its key is its field name in
the normalized representation. For example, if you render `MyApp.Weather`,
the render function will receive
`%{weather: normalized_schema, normalized_data: normalized_data}` as data.

More documentation can be found on [Hexdocs](https://hexdocs.pm/normalixr).