defmodule Normalixr.PhoenixView do
  @moduledoc """
  Support for rendering normalized representations generated by
  Normalixr.normalize/2. You can render this template by calling
  render(conn, Normalixr.PhoenixView, "normalized.json", assigns).

  The documentation for Normalixr.PhoenixView.render/2 contains information
  on which data the assigns must include.
  """

  @doc """
  Renders the fields of a normalized representation.

  ## Parameters

    - template_name: the name of this template, "normalized.json".
    - assigns: the assigned data and options.

  Assigns should be a map or keyword list with two fields, :data and
  :fields_to_render. The first is a normalized representation, the second a
  keyword list which contains a keyword list of options for each of the fields
  you want to render.

  The only option in the option list for a field in the normalized data which
  is required is :view, whose value is a the view module which contains the
  appropriate render function for those models.

  For example, if the field :city should be rendered with a render function in
  `MyApp.CityView`, you should set `:fields_to_render` to
  `[city: [view: MyApp.CityView]]`.

  By default, the template which is rendered is derived from the field name,
  so the field :city is rendered by the "city.json"-template. You can set
  :template to use another template.

    ## Example

      iex> data = Normalixr.normalize(%MyApp.Schemas.City{id: 1})
      ...> assigns = [data: data, fields_to_render: [city: [view: MyApp.CityView]]]
      ...> Normalixr.PhoenixView.render("normalized.json", assigns)
      %{data: %{city: %{1 => %{id: 1}}}}

  You can also set the `:except` and `:only` fields in the options. Both these
  fields are anonymous functions which take two arguments. The first is a tuple
  which has two elements: the second element is the model and the first its
  id. The second argument is the normalized data.

  These two functions should return either true or false. If only returns
  false or except returns true, the model isn't rendered.

  The final two options which can be set are :raise_if_no_results and
  :dont_render_if_empty. If the first option is set to true and the normalized
  representation contains no models of that type, a Normalixr.NoDataError
  is raised. By default, it is set to false.

  If the second option is set to true and the normalized representation
  contains no models of that type, the field is not rendered. Otherwise, it is
  set to an empty map. By default, it is set to true.

  If you don't want to put the rendered data into a field called data, you
  must set the following configuration option:
  config(:normalixr, :data_field, data_field)

  If data_field is set to false, the data will not be put into another map.
  Otherwise, data is replaced by whatever value is configured.
  """

  @spec render(String.t, map) :: map
  def render("normalized.json", assigns) do
    {normalized_data, fields_to_render} = extract_data_and_opts(assigns)

    filter = fn({field, opts}) ->
      no_data = is_nil normalized_data[field]
      raise_if_no_results = Keyword.get(opts, :raise_if_no_results, false)
      dont_render_if_empty = Keyword.get(opts, :dont_render_if_empty, true)

      cond do
        no_data and raise_if_no_results ->
          raise(Normalixr.NoDataError, message: "There is no data to be " <>
          "rendered, but the field #{inspect field} has been marked as " <>
          "required.")
        no_data and dont_render_if_empty -> false
        true -> true
      end
    end

    mapper = fn({field, opts}) ->
      {field, filter_and_render(field, normalized_data, opts)}
    end

    data = Normalixr.Util.filter_map_into(fields_to_render, filter, mapper)

    case Application.get_env(:normalixr, :data_field, :data) do
      false -> data
      field -> %{field => data}
    end
  end

  defp extract_data_and_opts(assigns) when is_list assigns do
    {Keyword.fetch!(assigns, :data), Keyword.fetch!(assigns, :fields_to_render)}
  end

  defp extract_data_and_opts(assigns) when is_map assigns do
    {assigns.data, assigns.fields_to_render}
  end

  defp filter_and_render(field, normalized_data, opts) do
    case normalized_data[field] do
      nil -> %{}
      data ->
        only = Keyword.get(opts, :only, fn(_, _) -> true end)
        except = Keyword.get(opts, :except, fn(_, _) -> false end)
        view = Keyword.fetch!(opts, :view)
        template = Keyword.get(opts, :template, Atom.to_string(field) <> ".json")

        filter = &(only.(&1, normalized_data) and not except.(&1, normalized_data))

        mapper = fn({id, model}) ->
          {id, view.render(template, [{field, model}, {:normalized_data, normalized_data}])}
        end

        Normalixr.Util.filter_map_into(data, filter, mapper)
    end
  end
end