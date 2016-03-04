defmodule Normalixr do
  @moduledoc """
  This module offers basic support to normalize nested Ecto models, merging
  normalized results, and backfilling has_on and belongs_to relations.
  """

  alias Ecto.Association.NotLoaded
  alias Ecto.Association.BelongsTo
  alias Ecto.Association.Has

  @doc """
  Normalizes an ecto schema or list of ecto schema which might contain deeply
  nested data.

  ## Parameters

    - model_or_models: An ecto schema or a list of ecto schemas
    - initial_result: The result of an earlier normalization. Defaults to an
    empty map.

  This function returns a single map, which is a normalized representation of
  the schema(s) it received. The second argument that can be passed should be
  the result of an earlier call to this function, because it will be used as
  initial value of the normalized representation that is returned.

  The keys of the map are determined by the modules that define the models.
  All but the last dot-separated block is ignored, this last block is
  converted to a lower-case atom with underscores.

  For example, if your module is called MyApp.Models.CityName, the key
  corresponding to these models in the normalized representation is :city_name.

  The keys each point to a map which contains only the data of that type.
  The key of a schema is its primary key.

  ## Example
      iex> Normalixr.normalize(%MyApp.Models.CityName{id: 1})
      %{city_name: %{1 => %MyApp.Models.CityName{id: 1}}}

  The results no longer contain any nested schemas. Every loaded
  association is replaced by a map with two keys, :field and :ids.
  The former has the key for those models, the latter contains a list of ids
  referenced by the model.

  ## Example
        iex> Normalixr.normalize(%City{id: 4, city_name: %CityName{id: 1}})
        %{city: %{4 => %City{id: 4, city_name: %{field: :city_name, ids: [1]}}},
          city_name: %{1 => %CityName{id: 1}}}

  As you can see the nesting has been lost.

  If a schema is inserted into the normalized representation which has
  already been set, a Normalixr.FieldMismatchError is raised if the field
  is set in both models and they don't match. If either value is nil,
  it is replaced if the other value is not nil.
  """

  #TODO support default values
  #TODO test backfilling BelongsTo and HasOne relations
  @spec normalize(Ecto.Schema.t | [Ecto.Schema.t], map) :: map
  def normalize(model_or_models, result \\ %{})

  def normalize(models, result) when is_list models and is_map result do
    Enum.reduce(models, result, &(normalize/2))
  end

  def normalize(model, result) when is_map model and is_map result do
    mod = model.__struct__

    {normalized_model, new_result} = mod.__schema__(:associations) # List of assocs
    |> Enum.map(&(parse_assoc(&1, model)))                         # Parse each assoc
    |> Enum.reduce({model, result}, &normalize_assoc/2)            # Normalize each assoc

    # Put the normalized model into the new results
    [pkey] = mod.__schema__(:primary_key)
    new_result = update_result({module_to_name(mod), %{Map.fetch!(normalized_model, pkey) => normalized_model}}, new_result)

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
      - opts: a keyword list, the keys should be the name of the models you
      want to backfill, the values the list of associations that should be
      backfilled for those models.

  ## Example
        iex> [%MyApp.Models.City{id: 1}, %MyApp.Models.Mayor{id: 2, city_id: 1}]
        ...> |> Normalixr.normalize
        ...> |> Normalixr.backfill(city: [:mayor], mayor: [:city])
        %{city: %{1 => %MyApp.Models.City{id: 1, mayor: %{field: :mayor, ids: [2]}}},
          mayor: %{2 => %MyApp.Models.Mayor{id: 2, city_id: 1, city: %{field: :city, ids: [1]}}}}

  As you can see, both the originally unloaded one-to-one relations have been backfilled.
  """

  @spec backfill(map, Keyword.t) :: map
  def backfill(result, []), do: result

  def backfill(result, opts) when is_list opts do
    Enum.reduce(opts, result, &(handle_field/2))
  end

  defp parse_assoc(assoc, model) when is_atom assoc do
    model.__struct__.__schema__(:association, assoc)
    |> parse_assoc(model)
  end

  defp parse_assoc(%BelongsTo{field: f, queryable: q, owner_key: o}, model) do
    %{field: f,
      data: Map.fetch!(model, f),
      mod: q,
      owner_key: o}
  end

  defp parse_assoc(%Has{cardinality: :one, field: f, queryable: q, related_key: r}, model) do
    %{field: f,
      data: Map.fetch!(model, f),
      mod: q,
      related_key: r}
  end

  defp parse_assoc(%{field: f, queryable: q}, model) do
    %{field: f,
      data: Map.fetch!(model, f),
      mod: q}
  end

  defp parse_assoc(%{field: f, through: t}, model) do
    %{field: f,
      data: Map.fetch!(model, f),
      mod: extract_module(t, model)}
  end

  defp extract_module(through, model, mod \\ nil) do
    Enum.reduce(through, mod, fn
      (thr, nil) ->
        case model.__struct__.__schema__(:association, thr) do
          %{queryable: queryable} -> queryable
          %{through: through} -> extract_module(through, model, mod)
        end
      (thr, mod) ->
        case mod.__schema__(:association, thr) do
          %{queryable: queryable} -> queryable
          %{through: through} -> extract_module(through, model, mod)
        end
    end)
  end

  defp normalize_assoc(%{data: %NotLoaded{}}, acc), do: acc # Ignore NotLoaded field

  defp normalize_assoc(%{data: [] = data, field: field, mod: mod}, {normalized_model, result}) do
    # Data has been loaded, but there are no results.
    {%{normalized_model | field => %{field: module_to_name(mod), ids: []}}, normalize(data, result)}
  end

  defp normalize_assoc(%{data: nil, field: field, mod: mod}, {normalized_model, result}) do
    # Data has been loaded, but there is no result
    {%{normalized_model | field => %{field: module_to_name(mod), ids: []}}, result}
  end

  defp normalize_assoc(%{data: data, field: field, mod: mod}, {normalized_model, result}) when is_list data do
    # Data has been loaded, there are many results
    name = module_to_name(mod)
    handle_many(mod, normalized_model, field, data, name, result)
  end

  defp normalize_assoc(%{data: data, field: field, mod: mod}, {normalized_model, result}) when is_map data do
    # A single piece of data has been loaded
    [pkey] = mod.__schema__(:primary_key)
    {%{normalized_model | field => %{field: module_to_name(mod), ids: [Map.fetch!(data, pkey)]}}, normalize(data, result)}
  end

  defp module_to_name(module) do
    try do
      module.name
    rescue
      _ ->
        [name] = ~r/[A-Za-z]+$/
        |> Regex.run(Atom.to_string(module))

        ~r/(?<!^)[A-Z](?=[a-z])/
        |> Regex.replace(name, "_\\0")
        |> String.downcase
        |> String.to_atom
    end
  end

  defp handle_many(mod, normalized_model, field, data, name, result) do
    [pkey] = mod.__schema__(:primary_key)
    ids = Enum.map(data, &(Map.fetch!(&1, pkey)))
    {%{normalized_model | field => %{field: name, ids: ids}}, normalize(data, result)}
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
    Enum.reduce(new_data, old_data, fn({id, model}, updated_data) ->
      case updated_data[id] do
        nil -> Map.put(updated_data, id, model) # New model
        ^model -> updated_data                  # Unchanged model
        current_model ->                        # Model has changed
          model = do_deep_merge(current_model, model)
          Map.put(updated_data, id, model)
      end
    end)
  end

  defp do_deep_merge(old_model, model) do
    merge_assocs(old_model, model)
    |> merge_fields(model)
  end

  defp merge_assocs(old_model, model) do
    model.__struct__.__schema__(:associations)
    |> Enum.reduce(old_model, fn(assoc_field, updated_model) ->
      updated_model_assoc = Map.fetch!(updated_model, assoc_field)
      new_model_assoc = Map.fetch!(model, assoc_field)

      case updated_model_assoc do
        ^new_model_assoc -> updated_model
        %NotLoaded{} -> Map.put(updated_model, assoc_field, new_model_assoc)
        %{ids: ids} ->
          case new_model_assoc do
            %NotLoaded{} -> updated_model
            %{ids: new_ids} = assoc_v ->
              assoc_v = %{assoc_v | ids: Enum.uniq(ids ++ new_ids)}
              Map.put(updated_model, assoc_field, assoc_v)
          end
      end
    end)
  end

  defp merge_fields(old_model, model) do
    model.__struct__.__schema__(:fields)
    |> Enum.reduce(old_model, fn(field, updated_model) ->
         updated_model_field = Map.fetch!(updated_model, field)
         new_model_field = Map.fetch!(model, field)

         case updated_model_field do
           ^new_model_field -> updated_model
           nil -> Map.put(updated_model, field, new_model_field)
           _ when is_nil new_model_field -> updated_model
           _ ->
             message = "The field #{inspect field} in the normalized data" <>
                       " doesn't match the new value. Current" <>
                       " value: #{inspect updated_model_field}, new" <>
                       " value: #{inspect new_model_field}"

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
      model_list ->
        x = model_list
        |> Enum.map(&(handle_model(&1, assoc, result)))
        |> Enum.into(%{})
        {name, x}
    end
  end

  defp handle_model({_, model} = m, assoc, updated_result) do
    case Map.fetch(model, assoc) do
      {:ok, %NotLoaded{}} ->
        parse_assoc(assoc, model)
        |> maybe_backfill_not_loaded(updated_result, m, assoc)
      {:ok, _} -> m
      _ -> raise Normalixr.NonexistentAssociation, "Association #{inspect assoc} does not exist in the schema #{inspect model.__struct__}."
    end
  end

  defp maybe_backfill_not_loaded(%{mod: mod, owner_key: o}, updated_result, {_, _} = m, assoc) do
    maybe_backfill_not_loaded(mod, o, updated_result, m, assoc)
  end

  defp maybe_backfill_not_loaded(%{mod: mod, related_key: r}, updated_result, {_, _} = m, assoc) do

    maybe_backfill_not_loaded(mod, r, updated_result, m, assoc)
  end

  defp maybe_backfill_not_loaded(mod, model_field, updated_result, {_, _} = m, assoc) do
    related_name = module_to_name(mod)
    maybe_do_backfill_not_loaded(model_field, related_name, updated_result[related_name], m, assoc)
  end

  defp maybe_do_backfill_not_loaded(_, _, nil, m, _), do: m

  defp maybe_do_backfill_not_loaded(model_field, related_name, map_of_models, {_, model} = m, assoc) when is_map(map_of_models) do
    case Map.get(model, model_field) do
      nil -> maybe_handle_has_one(model_field, related_name, map_of_models, m, assoc)
      related_model_id -> do_backfill_model(map_of_models[related_model_id], related_name, m, assoc)
    end
  end

  defp maybe_handle_has_one(model_field, related_name, map_of_models, {_, model} = m, assoc) do
    case Map.has_key?(model, model_field) do
      true -> m
      false -> maybe_do_backfill_has_one(model_field, related_name, map_of_models, m, assoc)
    end
  end

  defp maybe_do_backfill_has_one(model_field, related_name, map_of_models, {id, _} = m, assoc) do
    related_model = Enum.filter(map_of_models, fn({_, possibly_related_model}) ->
      case Map.fetch!(possibly_related_model, model_field) do
        ^id -> true
        _ -> false
      end
    end)

    case related_model do
      [] -> m
      [{_, related_model}] -> do_backfill_model(related_model, related_name, m, assoc)
      _ -> raise("")
    end
  end

  defp do_backfill_model(nil, _, {_, _} = m, _), do: m

  defp do_backfill_model(related_model, related_name, {id, model}, assoc) do
    [pkey] = related_model.__struct__.__schema__(:primary_key)
    related_id = Map.fetch!(related_model, pkey)
    new_assoc_field = %{field: related_name, ids: [related_id]}
    backfilled_model = Map.put(model, assoc, new_assoc_field)
    {id, backfilled_model}
  end
end