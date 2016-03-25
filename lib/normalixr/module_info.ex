defmodule Normalixr.ModuleInfo do
  @moduledoc false

  alias Normalixr.Association.BelongsTo, as: BT
  alias Normalixr.Association.Has, as: H
  alias Normalixr.Association.HasThrough, as: HT
  alias Normalixr.Association.ManyToMany, as: MTM

  alias Ecto.Association.BelongsTo
  alias Ecto.Association.Has
  alias Ecto.Association.HasThrough
  alias Ecto.Association.ManyToMany

  def extract_assocs(mod) do
    mod.__schema__(:associations)
    |> Enum.map(&(parse_assoc(mod, &1)))
    |> Enum.into(%{})
  end

  defp parse_assoc(mod, assoc) when is_atom(assoc) and is_atom(mod) do
    assoc_struct = mod.__schema__(:association, assoc)
    |> parse_assoc(mod)

    {assoc, assoc_struct}
  end

  defp parse_assoc(%BelongsTo{field: f, queryable: q, related_key: r, owner_key: o}, _) do
    %BT{field:       f,
        mod:         q,
        related_key: r,
        owner_key:   o}
  end

  defp parse_assoc(%Has{cardinality: c, field: f, queryable: q, related_key: r, owner_key: o}, _) do
    %H{cardinality: c,
       field:       f,
       mod:         q,
       owner_key:   o,
       related_key: r}
  end

  defp parse_assoc(%ManyToMany{field: f, queryable: q}, _) do
    %MTM{field: f,
         mod: q}
  end

  defp parse_assoc(%HasThrough{field: f, cardinality: c, through: t}, mod) do
    %HT{field: f,
        cardinality: c,
        through: t,
        mods: extract_modules(mod, t) |> Enum.reverse}
  end

  defp extract_modules(mod, t, acc \\ [])

  defp extract_modules(_, [], acc), do: acc

  defp extract_modules(mod, [assoc | t], acc) do
    case mod.__schema__(:association, assoc) do
      %Has{queryable: q, cardinality: c}  ->
        extract_modules(q, t, [{assoc, {q, c}} | acc])
      %BelongsTo{queryable: q, cardinality: c}  ->
        extract_modules(q, t, [{assoc, {q, c}} | acc])
      %HasThrough{through: through} ->
        [{_, {q, _}}|_] = new_acc = extract_modules(mod, through, acc)
        extract_modules(q, t, new_acc)
    end
  end
end