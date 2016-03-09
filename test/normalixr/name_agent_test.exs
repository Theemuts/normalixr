defmodule Normalixr.NameAgentTest do
  use ExUnit.Case
  alias Normalixr.NameAgent

  test "Returns underscored name" do
    assert NameAgent.get(NameAgent, MyApp.NameTest) == :name_test
  end
end