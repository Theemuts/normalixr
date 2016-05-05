
defmodule MyApp.Schemas.Friend do
  @moduledoc false

  use Normalixr.Schema
  alias MyApp.Schemas.Mayor
  alias MyApp.Schemas.FriendName

  schema "friend" do
    belongs_to :friend_name, FriendName
    belongs_to :mayor, Mayor

    timestamps
  end
end

