defmodule Root.Repo.Migrations.CreateUpstreamConfigs do
  use Ecto.Migration

  def change do
    create table(:upstream_configs, primary_key: false) do
      add :id, :string, primary_key: true
      add :command, :string, null: false
      add :args, {:array, :string}, null: false, default: []
      add :env, :map, null: false, default: %{}
      add :cwd, :string
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end
  end
end
