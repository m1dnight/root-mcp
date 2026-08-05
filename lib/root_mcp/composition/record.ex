defmodule Root.Composition.Record do
  @moduledoc """
  Ecto schema for persisted compositions.

  Persistence shape only — the domain struct is `Root.Composition`, and
  `Root.Composition.Store` converts between the two.
  """

  use Ecto.Schema

  @primary_key {:name, :string, autogenerate: false}
  schema "compositions" do
    field :description, :string
    field :input_schema, :map
    field :code, :string
    field :enabled, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}
end
