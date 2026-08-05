defmodule Root.MCP.UpstreamConfigTest do
  use Root.DataCase, async: false

  alias Root.MCP.Upstream.Config
  alias Root.MCP.Upstream.Config.Store
  alias Root.Vault

  @valid %{
    id: "pg",
    command: "uvx",
    args: ["postgres-mcp"],
    env: %{"DATABASE_URI" => %{"$secret" => "db-url"}, "LOG_LEVEL" => "info"}
  }

  describe "new/1" do
    test "builds a valid config with defaults" do
      assert {:ok, %Config{id: "pg", enabled: true, cwd: nil}} = Config.new(@valid)
    end

    test "rejects bad ids, missing commands, and malformed env values" do
      assert {:error, message} = Config.new(%{@valid | id: "Bad_Id"})
      assert message =~ "lowercase"

      assert {:error, message} = Config.new(Map.delete(@valid, :command))
      assert message =~ "command"

      assert {:error, message} = Config.new(%{@valid | env: %{"X" => %{"$vault" => "nope"}}})
      assert message =~ "env values"

      assert {:error, message} = Config.new(%{@valid | args: ["ok", %{"$vault" => "nope"}]})
      assert message =~ "args must be"
    end

    test "accepts reference maps in args" do
      assert {:ok, %Config{args: ["--api-key", %{"$secret" => "api-key"}]}} =
               Config.new(%{@valid | args: ["--api-key", %{"$secret" => "api-key"}]})
    end
  end

  describe "resolve_env/1" do
    test "resolves literals, host env references, and vault references" do
      System.put_env("ROOT_TEST_ENV_REF", "from-host")
      on_exit(fn -> System.delete_env("ROOT_TEST_ENV_REF") end)
      :ok = Vault.put("db-url", "postgresql://secret@host/db")

      assert {:ok,
              %{
                "A" => "literal",
                "B" => "from-host",
                "C" => "postgresql://secret@host/db"
              }} =
               Config.resolve_env(%{
                 "A" => "literal",
                 "B" => %{"$env" => "ROOT_TEST_ENV_REF"},
                 "C" => %{"$secret" => "db-url"}
               })
    end

    test "resolves references in args, preserving order" do
      :ok = Vault.put("api-key", "sk-hunter2")

      assert {:ok, ["--api-key", "sk-hunter2", "serve"]} =
               Config.resolve_args(["--api-key", %{"$secret" => "api-key"}, "serve"])

      assert {:error, {:missing_secret, "ghost"}} =
               Config.resolve_args([%{"$secret" => "ghost"}])
    end

    test "names the missing reference on failure" do
      assert {:error, {:missing_env, "ROOT_TEST_ABSENT"}} =
               Config.resolve_env(%{"X" => %{"$env" => "ROOT_TEST_ABSENT"}})

      assert {:error, {:missing_secret, "ghost"}} =
               Config.resolve_env(%{"X" => %{"$secret" => "ghost"}})
    end
  end

  describe "Store" do
    test "round-trips configs including env and args references" do
      {:ok, config} = Config.new(%{@valid | args: ["postgres-mcp", %{"$secret" => "db-url"}]})
      assert :ok = Store.put(config)

      assert %Config{
               env: %{"DATABASE_URI" => %{"$secret" => "db-url"}},
               args: ["postgres-mcp", %{"$secret" => "db-url"}]
             } = Store.get("pg")

      {:ok, disabled} = Config.new(Map.put(@valid, :enabled, false))
      assert :ok = Store.put(disabled)
      assert [%Config{id: "pg"}] = Store.list()
      assert Store.list_enabled() == []

      assert :ok = Store.delete("pg")
      assert Store.list() == []
      assert {:error, :not_found} = Store.delete("pg")
    end
  end
end
