defmodule Normalixr.PhoenixView
  @spec render(String.t, map, Keyword.t) :: map
  def render("normalized.json", normalized_data, fields_to_render) do
    Enum.map(fields_to_render, fn({field, opts}) ->
      only = Keyword.get(opts, :only, fn(_) -> true end)
      except = Keyword.get(opts, :except, fn(_) -> false end)
      view = Keyword.fetch(opts, :view)
      template = Keyword.get(opts, :template, Atom.to_string(field) <> ".json")
      raise_if_no_results = Keyword.get(opts, :allow_no_results, false)
      dont_render_if_empty = Keyword.get(opts, :dont_render_if_empty, true)

      data = normalized_data[field]
      no_data = is_nil data

      if raise_if_no_results and no_data, do: raise "No data"

      if dont_render_if_empty and no_data do
        :ignore
      else
        {field, filter_and_render(data, only, except, view, template)}    
      end
    end)
    |> Enum.filter(&(&1 != :ignore))
    |> Enum.into(%{})
  end

  defp filter_and_render(nil, _, _, _, _), do: %{}

  defp filter_and_render(data, only, except, view, template) do
    Enum.filter_map(data, &(only.(&1) and not except.(&1)), fn({id, model}) -> 
      rendered_model = view.render(template, [{field, model}, {:normalized_data, normalized_data}])
      {id, rendered_model}
    end)
    |> Enum.into(%{})
  end
end