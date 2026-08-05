defmodule Root.VaultTest do
  use Root.DataCase, async: false

  alias Root.Vault

  test "puts, fetches, overwrites, lists, and deletes secrets" do
    assert Vault.fetch("db-url") == :error

    assert :ok = Vault.put("db-url", "postgresql://user:hunter2@localhost/prod")
    assert {:ok, "postgresql://user:hunter2@localhost/prod"} = Vault.fetch("db-url")

    assert :ok = Vault.put("db-url", "postgresql://rotated@localhost/prod")
    assert {:ok, "postgresql://rotated@localhost/prod"} = Vault.fetch("db-url")

    assert :ok = Vault.put("api-key", "sk-123")
    assert Vault.list() == ["api-key", "db-url"]

    assert :ok = Vault.delete("api-key")
    assert Vault.list() == ["db-url"]
    assert {:error, :not_found} = Vault.delete("api-key")
  end

  test "values are encrypted at rest" do
    :ok = Vault.put("token", "super-secret-value")

    stored = Repo.get(Root.Vault.Record, "token").value
    refute stored =~ "super-secret-value"
  end
end
