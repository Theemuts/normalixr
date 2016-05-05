defmodule Normalixr do
  @moduledoc """
  This module offers basic support to normalize nested Ecto schemas, merging
  normalized results, and backfilling has_on and belongs_to relations.

  In order to use this library, you need to replace any instance of
  `use Ecto.Schema` with `use Normalixr.Schema, mod: __MODULE__`. This creates two
  new functions, `underscored_name/0` and `normalixr_assocs/0`.
  """

  alias Ecto.Association.NotLoaded
  alias Normalixr.Association.BelongsTo
  alias Normalixr.Association.Has
  alias Normalixr.Association.HasThrough

  @doc """
  Normalizes an ecto schema or list of ecto schema which might contain deeply
  nested data.

  ## Parameters

    - schema_or_schemas: An ecto schema or a list of ecto schemas
    - initial_result: The result of an earlier normalization. Defaults to an
    empty map.

  This function returns a single map, which is a normalized representation of
  the schema(s) it received. The second argument that can be passed should be
  the result of an earlier call to this function, because it will be used as
  initial value of the normalized representation that is returned.

  The keys of the map are determined by the modules that define the schemas.
  All but the last dot-separated block is ignored, this last block is
  converted to a lower-case atom with underscores.

  For example, if your module is called MyApp.Schemas.CityName, the key
  corresponding to these schemas in the normalized representation is
  :city_name.

  You can override these default values by overriding `underscored_name/0`
  with a function which returns the name as an atom. For example, if you
  want `MyApp.Weather.Home` to have the key `:weather_home`, you should
  define `def underscored_name, do: :weather_home`.

  The keys each point to a map which contains only the data of that type.
  The key of a schema is its primary key.

  ## Example

      iex> Normalixr.normalize(%MyApp.Schemas.CityName{id: 1})
      %{city_name: %{1 => %MyApp.Schemas.CityName{id: 1}}}

  The results no longer contain any nested schemas. Every loaded
  association is replaced by a map with two keys, :field and :ids.
  The former has the key for those schemas, the latter contains a list of ids
  referenced by the schema.

  ## Example

      iex> Normalixr.normalize(%City{id: 4, city_name: %CityName{id: 1}})
      %{city: %{4 => %City{id: 4, city_name: %{field: :city_name, ids: [1]}}},
        city_name: %{1 => %CityName{id: 1}}}

  As you can see the nesting has been lost.

  If a schema is inserted into the normalized representation which has
  already been set, a Normalixr.FieldMismatchError is raised if the field
  is set in both schemas and they don't match. If either value is nil,
  it is replaced if the other value is not nil.
  """

  @spec normalize(Ecto.Schema.t | [Ecto.Schema.t], map) :: map
  def normalize(schema_or_schemas, result \\ %{})

  def normalize(schemas, result) when is_list schemas and is_map result do
    Enum.reduce(schemas, result, &(normalize/2))
  end

  def normalize(schema, result) when is_map schema and is_map result do
    mod = schema.__struct__

    {normalized_schema, new_result} = mod.normalixr_assocs        # List of assocs
    |> Enum.reduce({schema, result}, &normalize_assoc/2)          # Normalize each assoc

    # Put the normalized schema into the new results
    [pkey] = mod.__schema__(:primary_key)
    new_result = update_result({mod.underscored_name, %{Map.fetch!(normalized_schema, pkey) => normalized_schema}}, new_result)

    # Merge the old and new results
    merge(new_result, result)
  end

  @doc """
  Merge one or more normalized representations.

  ## Parameters

    - result_or_results: a normalized representation, or list of normalized
    representations.
    - initial_result: a normalized representation, optional when a list of
    normalized representations is passed as the first argument.
  """

  @spec merge([map]|map, map) :: map
  def merge(result_or_results, initial_result \\ %{})

  def merge(results, initial_result) when is_list results and is_map initial_result do
    Enum.reduce(results, initial_result, &(merge/2))
  end

  def merge(new_result, initial_result) when is_map initial_result and is_map new_result do
    Enum.reduce(new_result, initial_result, &(update_result/2))
  end

  @doc """
  Backfill has_one (through) and belongs_to associations if the data has
  already been loaded.

  ## Parameters

    - result: a normalized representation.
    - opts: a keyword list, the keys should be the name of the schemas you
    want to backfill, the values the list of associations that should be
    backfilled for those schemas.

  ## Example

      iex> [%MyApp.Schemas.City{id: 1}, %MyApp.Schemas.Mayor{id: 2, city_id: 1}]
      ...> |> Normalixr.normalize
      ...> |> Normalixr.backfill(city: [:mayor], mayor: [:city])
      %{city: %{1 => %MyApp.Schemas.City{id: 1, mayor: %{field: :mayor, ids: [2]}}},
        mayor: %{2 => %MyApp.Schemas.Mayor{id: 2, city_id: 1, city: %{field: :city, ids: [1]}}}}

  As you can see, both the originally unloaded one-to-one relations have been backfilled.

  If you try to backfill unsupported associations, a Normalixr.UnsupportedAssociation
  error is raised.
  """

  @spec backfill(map, Keyword.t) :: map
  def backfill(result, []), do: result

  def backfill(result, opts) when is_list opts do
    Enum.reduce(opts, result, &(handle_field/2))
  end

  defp normalize_assoc({assoc, _} = ass, {normalized_schema, _} = acc) do
    data = Map.get(normalized_schema, assoc)
    normalize_assoc(data, ass, acc)
  end

  defp normalize_assoc(%NotLoaded{}, _, acc), do: acc

  defp normalize_assoc(data, {assoc, %{mod: mod}}, {normalized_schema, result}) when is_map data do
    [pkey] = mod.__schema__(:primary_key)
    {%{normalized_schema | assoc => %{field: mod.underscored_name, ids: [Map.fetch!(data, pkey)]}}, normalize(data, result)}
  end

  defp normalize_assoc(data, {assoc, %{mod: mod}}, {normalized_schema, result})
      when is_nil(data)
      when data == [] do
    {%{normalized_schema | assoc => %{field: mod.underscored_name, ids: []}}, result}
  end

  defp normalize_assoc(data, {assoc, %{mod: mod}}, {normalized_schema, result}) when is_list(data) do
    [pkey] = mod.__schema__(:primary_key)
    ids = Enum.map(data, &(Map.fetch!(&1, pkey)))

    {%{normalized_schema | assoc => %{field: mod.underscored_name, ids: ids}}, normalize(data, result)}
  end

  defp update_result({name, data}, result) do
    data = deep_merge(result[name], data)
    Map.put(result, name, data)
  end

  defp deep_merge(nil, data), do: data

  defp deep_merge(old_data, new_data) do
    Enum.reduce(new_data, old_data, fn({id, schema}, updated_data) ->
      case updated_data[id] do
        nil -> Map.put(updated_data, id, schema) # New schema
        ^schema -> updated_data                  # Unchanged schema
        current_schema ->                        # Schema has changed
          schema = do_deep_merge(current_schema, schema)
          Map.put(updated_data, id, schema)
      end
    end)
  end

  defp do_deep_merge(old_schema, schema) do
    old_schema
    |> merge_assocs(schema)
    |> merge_fields(schema)
  end

  defp merge_assocs(old_schema, schema) do
    schema.__struct__.__schema__(:associations)
    |> Enum.reduce(old_schema, fn(assoc_field, updated_schema) ->
      updated_schema_assoc = Map.fetch!(updated_schema, assoc_field)
      new_schema_assoc = Map.fetch!(schema, assoc_field)

      case updated_schema_assoc do
        ^new_schema_assoc -> updated_schema
        %NotLoaded{} -> Map.put(updated_schema, assoc_field, new_schema_assoc)
        %{ids: ids} ->
          case new_schema_assoc do
            %NotLoaded{} -> updated_schema
            %{ids: new_ids} = assoc_v ->
              assoc_v = %{assoc_v | ids: Enum.uniq(ids ++ new_ids)}
              Map.put(updated_schema, assoc_field, assoc_v)
          end
      end
    end)
  end

  defp merge_fields(old_schema, schema) do
    schema.__struct__.__schema__(:fields)
    |> Enum.reduce(old_schema, fn(field, updated_schema) ->
         updated_schema_field = Map.fetch!(updated_schema, field)
         new_schema_field = Map.fetch!(schema, field)

         case updated_schema_field do
           ^new_schema_field -> updated_schema
           nil -> Map.put(updated_schema, field, new_schema_field)
           _ when is_nil new_schema_field -> updated_schema
           _ ->
             message = "The field #{inspect field} in the normalized data" <>
                       " doesn't match the new value. Current" <>
                       " value: #{inspect updated_schema_field}, new" <>
                       " value: #{inspect new_schema_field}"

             raise Normalixr.FieldMismatchError, message: message
         end
       end)
  end

  defp handle_field({name, assoc_list}, result) do
    Enum.reduce(assoc_list, result, &(handle_assoc(&1, &2, name)))
  end

  defp handle_assoc(assoc, result, name) do
    handle_assoc(result[name], assoc, result, name)
  end

  defp handle_assoc(nil, _, result, _), do: result

  defp handle_assoc(schema_list, assoc, result, name) do
    updated_schema_list = schema_list
    |> Enum.map(&(handle_schema(&1, assoc, result)))
    |> Enum.into(%{})

    update_result({name, updated_schema_list}, result)
  end

  defp handle_schema({_, schema} = m, assoc, result) do
    handle_schema(schema.__struct__.normalixr_assocs[assoc], m, assoc, result)
  end

  defp handle_schema(nil, {_, schema}, assoc, _) do
    raise Normalixr.NonexistentAssociation, "Association #{inspect assoc} does not exist in the schema #{inspect schema.__struct__}."
  end

  defp handle_schema(%BelongsTo{} = assoc_struct, {_, _} = m, assoc, result) do
    handle_belongs_to(assoc_struct, m, assoc, result)
  end

  defp handle_schema(%Has{cardinality: :one} = assoc_struct, {_, _} = m, assoc, result) do
    handle_has(assoc_struct, m, assoc, result)
  end

  defp handle_schema(%HasThrough{cardinality: :one} = assoc_struct, {_, _} = m, assoc, result) do
    handle_has_through(assoc_struct, m, assoc, result)
  end

  defp handle_schema(_, _, assoc, _) do
    raise Normalixr.UnspportedAssociation, "The association #{inspect assoc} cannot be backfilled, because it is not a has_one, has_one through, or belongs_to relationship."
  end

  defp handle_belongs_to(%BelongsTo{field: field} = assoc_struct, {id, schema} = m, assoc, result) do
    related_id = Map.fetch!(schema, assoc_struct.owner_key)

    case Map.get(result, field, %{})[related_id] do
      nil -> m
      related_schema when is_map related_schema ->
        field = related_schema.__struct__.underscored_name
        schema = %{schema | assoc => %{field: field, ids: [related_id]}}
        {id, schema}
    end
  end

  defp handle_has(%Has{related_key: related_key, owner_key: owner_key, mod: mod}, {_, schema} = m, assoc, result) do

    related_schemas = Map.get(result, mod.underscored_name, %{})
    owner_id = Map.fetch!(schema, owner_key)

    filter = fn({_id, datum}) ->
      Map.fetch!(datum, related_key) == owner_id
    end

    case Enum.filter(related_schemas, filter) do
      [] -> m
      [{_, related_schema}] -> update_schema(m, assoc, related_schema)
      _ -> raise Normalixr.TooManyResultsError
    end
  end

  defp handle_has_through(%HasThrough{mods: mods}, {_, schema} = m, assoc, result) do
    related_schema = Enum.reduce(mods, schema, fn({field, {_, _}}, current_schema) ->
      case Map.fetch!(current_schema, field) do
        %{field: field, ids: [id]} ->
          Map.get(result, field, %{})[id]
        _ ->
          nil
      end
    end)

    update_schema(m, assoc, related_schema)
  end

  defp update_schema({_, _} = m, _, nil), do: m

  defp update_schema({id, schema}, assoc, related_schema) when is_map related_schema do
    mod = related_schema.__struct__
    [pkey] = mod.__schema__(:primary_key)
    related_id = Map.fetch!(related_schema, pkey)
    new_assoc_field = %{field: mod.underscored_name, ids: [related_id]}
    {id, %{schema | assoc => new_assoc_field}}
  end
end