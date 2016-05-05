defmodule MyApp.Schemas.FriendName do
  @moduledoc false

  use Normalixr.Schema
  alias MyApp.Schemas.Friend

  schema "friend_name" do
    field :name
    has_many :friends, Friend
  end
end