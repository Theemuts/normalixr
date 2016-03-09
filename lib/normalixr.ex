defmodule Normalixr do
  @moduledoc """
  This module offers basic support to normalize nested Ecto schemas, merging
  normalized results, and backfilling has_on and belongs_to relations.
  """

  use Application

  alias Ecto.Association.NotLoaded
  alias Ecto.Association.BelongsTo
  alias Ecto.Association.Has

  def start(_, _) do
    import Supervisor.Spec, warn: false

    default_names = Application.get_env(:normalixr, :default_names, %{})

    children = [
      worker(Normalixr.NameAgent, [Normalixr.NameAgent, default_names])
    ]

    opts = [strategy: :one_for_one, name: Normalixr.Supervisor]

    Supervisor.start_link(children, opts)
  end

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

  You can override these default values by setting a map with default names in
  your config. For example, if you want the module MyApp.Telephone.User to
  be assigned to the field :telephone_user, you can set the :default_names
  key in your configuration:
  config :normalixr, :default_names, %{"MyApp.Telephone.User" => :telephone_user}

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

    {normalized_schema, new_result} = mod.__schema__(:associations) # List of assocs
    |> Enum.map(&(parse_assoc(&1, schema)))                         # Parse each assoc
    |> Enum.reduce({schema, result}, &normalize_assoc/2)            # Normalize each assoc

    # Put the normalized schema into the new results
    [pkey] = mod.__schema__(:primary_key)
    new_result = update_result({module_to_name(mod), %{Map.fetch!(normalized_schema, pkey) => normalized_schema}}, new_result)

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
  Backfill has_one and belongs_to associations if the data has already been
  loaded.

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
  """

  @spec backfill(map, Keyword.t) :: map
  def backfill(result, []), do: result

  def backfill(result, opts) when is_list opts do
    Enum.reduce(opts, result, &(handle_field/2))
  end

  defp parse_assoc(assoc, schema) when is_atom assoc do
    schema.__struct__.__schema__(:association, assoc)
    |> parse_assoc(schema)
  end

  defp parse_assoc(%BelongsTo{field: f, queryable: q, owner_key: o}, schema) do
    %{field: f,
      data: Map.fetch!(schema, f),
      mod: q,
      owner_key: o}
  end

  defp parse_assoc(%Has{cardinality: :one, field: f, queryable: q, related_key: r}, schema) do
    %{field: f,
      data: Map.fetch!(schema, f),
      mod: q,
      related_key: r}
  end

  defp parse_assoc(%{field: f, queryable: q}, schema) do
    %{field: f,
      data: Map.fetch!(schema, f),
      mod: q}
  end

  defp parse_assoc(%{field: f, through: t}, schema) do
    %{field: f,
      data: Map.fetch!(schema, f),
      mod: extract_module(t, schema)}
  end

  defp extract_module(through, schema, mod \\ nil) do
    Enum.reduce(through, mod, fn
      (thr, nil) ->
        case schema.__struct__.__schema__(:association, thr) do
          %{queryable: queryable} -> queryable
          %{through: through} -> extract_module(through, schema, mod)
        end
      (thr, mod) ->
        case mod.__schema__(:association, thr) do
          %{queryable: queryable} -> queryable
          %{through: through} -> extract_module(through, schema, mod)
        end
    end)
  end

  defp normalize_assoc(%{data: %NotLoaded{}}, acc), do: acc # Ignore NotLoaded field

  defp normalize_assoc(%{data: [] = data, field: field, mod: mod}, {normalized_schema, result}) do
    # Data has been loaded, but there are no results.
    {%{normalized_schema | field => %{field: module_to_name(mod), ids: []}}, normalize(data, result)}
  end

  defp normalize_assoc(%{data: nil, field: field, mod: mod}, {normalized_schema, result}) do
    # Data has been loaded, but there is no result
    {%{normalized_schema | field => %{field: module_to_name(mod), ids: []}}, result}
  end

  defp normalize_assoc(%{data: data, field: field, mod: mod}, {normalized_schema, result}) when is_list data do
    # Data has been loaded, there are many results
    name = module_to_name(mod)
    handle_many(mod, normalized_schema, field, data, name, result)
  end

  defp normalize_assoc(%{data: data, field: field, mod: mod}, {normalized_schema, result}) when is_map data do
    # A single piece of data has been loaded
    [pkey] = mod.__schema__(:primary_key)
    {%{normalized_schema | field => %{field: module_to_name(mod), ids: [Map.fetch!(data, pkey)]}}, normalize(data, result)}
  end

  defp module_to_name(module) do
    alias Normalixr.NameAgent
    NameAgent.get(NameAgent, module)
  end

  defp handle_many(mod, normalized_schema, field, data, name, result) do
    [pkey] = mod.__schema__(:primary_key)
    ids = Enum.map(data, &(Map.fetch!(&1, pkey)))
    {%{normalized_schema | field => %{field: name, ids: ids}}, normalize(data, result)}
  end

  defp update_result({name, data}, result) do
    case result[name] do
      nil ->
        Map.put(result, name, data)
      val ->
        Map.put(result, name, deep_merge(val, data))
    end
  end

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
    merge_assocs(old_schema, schema)
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
    |> update_result(result)
  end

  defp handle_assoc(assoc, result, name) do
    case result[name] do
      nil ->
        {name, []}
      schema_list ->
        x = schema_list
        |> Enum.map(&(handle_schema(&1, assoc, result)))
        |> Enum.into(%{})
        {name, x}
    end
  end

  defp handle_schema({_, schema} = m, assoc, updated_result) do
    case Map.fetch(schema, assoc) do
      {:ok, %NotLoaded{}} ->
        parse_assoc(assoc, schema)
        |> maybe_backfill_not_loaded(updated_result, m, assoc)
      {:ok, _} -> m
      _ -> raise Normalixr.NonexistentAssociation, "Association #{inspect assoc} does not exist in the schema #{inspect schema.__struct__}."
    end
  end

  defp maybe_backfill_not_loaded(%{mod: mod, owner_key: o}, updated_result, {_, _} = m, assoc) do
    maybe_backfill_not_loaded(mod, o, updated_result, m, assoc)
  end

  defp maybe_backfill_not_loaded(%{mod: mod, related_key: r}, updated_result, {_, _} = m, assoc) do

    maybe_backfill_not_loaded(mod, r, updated_result, m, assoc)
  end

  defp maybe_backfill_not_loaded(mod, schema_field, updated_result, {_, _} = m, assoc) do
    related_name = module_to_name(mod)
    maybe_do_backfill_not_loaded(schema_field, related_name, updated_result[related_name], m, assoc)
  end

  defp maybe_do_backfill_not_loaded(_, _, nil, m, _), do: m

  defp maybe_do_backfill_not_loaded(schema_field, related_name, map_of_schemas, {_, schema} = m, assoc) when is_map(map_of_schemas) do
    case Map.get(schema, schema_field) do
      nil -> maybe_handle_has_one(schema_field, related_name, map_of_schemas, m, assoc)
      related_schema_id -> do_backfill_schema(map_of_schemas[related_schema_id], related_name, m, assoc)
    end
  end

  defp maybe_handle_has_one(schema_field, related_name, map_of_schemas, {_, schema} = m, assoc) do
    case Map.has_key?(schema, schema_field) do
      true -> m
      false -> maybe_do_backfill_has_one(schema_field, related_name, map_of_schemas, m, assoc)
    end
  end

  defp maybe_do_backfill_has_one(schema_field, related_name, map_of_schemas, {id, _} = m, assoc) do
    related_schema = Enum.filter(map_of_schemas, fn({_, possibly_related_schema}) ->
      case Map.fetch!(possibly_related_schema, schema_field) do
        ^id -> true
        _ -> false
      end
    end)

    case related_schema do
      [] -> m
      [{_, related_schema}] -> do_backfill_schema(related_schema, related_name, m, assoc)
      _ -> raise("")
    end
  end

  defp do_backfill_schema(nil, _, {_, _} = m, _), do: m

  defp do_backfill_schema(related_schema, related_name, {id, schema}, assoc) do
    [pkey] = related_schema.__struct__.__schema__(:primary_key)
    related_id = Map.fetch!(related_schema, pkey)
    new_assoc_field = %{field: related_name, ids: [related_id]}
    backfilled_schema = Map.put(schema, assoc, new_assoc_field)
    {id, backfilled_schema}
  end
end