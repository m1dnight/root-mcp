defmodule Root.Repo.Migrations.CreateCompositions do
  use Ecto.Migration

  def change do
    create table(:compositions, primary_key: false) do
      add :name, :string, primary_key: true
      add :description, :text, null: false
      add :input_schema, :map, null: false
      add :code, :text, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
