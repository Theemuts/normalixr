defmodule MyApp.Schemas.Contact do
  @moduledoc false
  use Normalixr.Schema

  schema "contact" do
    field :name
    field :contact_id

    has_one :associated_contact, __MODULE__, foreign_key: :contact_id
  end
end