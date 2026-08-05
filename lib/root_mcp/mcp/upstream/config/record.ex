defmodule Root.MCP.Upstream.Config.Record do
  @moduledoc """
  Ecto schema for persisted upstream configs. Persistence shape only —
  the domain struct is `Root.MCP.Upstream.Config`.
  """

  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "upstream_configs" do
    field :command, :string
    # args may mix literal strings and reference maps; same JSON-text storage
    field :args, Root.EctoJSON
    field :env, :map
    field :cwd, :string
    field :enabled, :boolean

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}
end
