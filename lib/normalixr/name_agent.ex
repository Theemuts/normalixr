defmodule Normalixr.NameAgent do
  @moduledoc false

  def start_link(name, default_names) do

    Agent.start_link(fn -> default_names end, name: name)
  end

  def get(agent, module) do
    "Elixir." <> mod_name = Atom.to_string(module)

    case Agent.get(agent, &Map.get(&1, mod_name)) do
      nil ->
        pascal_case = module
        |> Module.split
        |> List.last

        val = ~r/(?<!^)[A-Z](?=[a-z])/
        |> Regex.replace(pascal_case, "_\\0")
        |> String.downcase
        |> String.to_atom

        put(Normalixr.NameAgent, mod_name, val)
      val -> val
    end
  end

  defp put(agent, name, field) do
    Agent.update(agent, &Map.put(&1, name, field))
    field
  end
end