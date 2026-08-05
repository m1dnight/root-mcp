defmodule Root.Repo.Migrations.AddEnabledToCompositions do
  use Ecto.Migration

  def change do
    alter table(:compositions) do
      add :enabled, :boolean, null: false, default: true
    end
  end
end
