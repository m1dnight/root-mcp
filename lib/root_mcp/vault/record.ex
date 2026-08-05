defmodule Root.Vault.Record do
  @moduledoc """
  Ecto schema for vault secrets. The value column holds the encrypted
  token, never plaintext — all access goes through `Root.Vault`.
  """

  use Ecto.Schema

  @primary_key {:name, :string, autogenerate: false}
  schema "secrets" do
    field :value, :binary

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}
end
