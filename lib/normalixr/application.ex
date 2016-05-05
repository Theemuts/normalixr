defmodule Normalixr.Application do
  @moduledoc false
  use Application

  @doc false
  def start(_, _) do
    import Supervisor.Spec

    opts = [strategy: :one_for_one, name: Normalixr.Supervisor]
    children = [worker(Normalixr.ETS, [])]
    Supervisor.start_link(children, opts)
  end
end