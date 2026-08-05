defmodule RootWeb.UpstreamLiveTest do
  use RootWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Root.MCP.Upstream.Config
  alias Root.MCP.Upstream.Config.Store

  @moduletag :capture_log

  test "adds, edits, toggles, and deletes upstream configs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/upstreams")

    view
    |> form("#upstream-form",
      config: %{
        id: "pg",
        command: "uvx",
        args: "--with\nmcp<2\npostgres-mcp\n{\"$secret\": \"db-url\"}",
        env: ~s({"DATABASE_URI": {"$secret": "db-url"}}),
        cwd: "",
        enabled: "true"
      }
    )
    |> render_submit()

    assert has_element?(view, "#upstream-pg")

    assert %Config{
             command: "uvx",
             args: ["--with", "mcp<2", "postgres-mcp", %{"$secret" => "db-url"}],
             env: %{"DATABASE_URI" => %{"$secret" => "db-url"}},
             enabled: true
           } = Store.get("pg")

    # edit: form is prefilled, id is read-only, command change persists
    view |> element("#upstream-pg button", "edit") |> render_click()
    assert view |> element("#upstream-form") |> render() =~ "postgres-mcp"

    view
    |> form("#upstream-form",
      config: %{
        command: "uv",
        args: "tool\nrun\npostgres-mcp",
        env: ~s({"DATABASE_URI": {"$secret": "db-url"}}),
        enabled: "true"
      }
    )
    |> render_submit()

    assert %Config{id: "pg", command: "uv"} = Store.get("pg")

    view |> element("#upstream-pg button", "disable") |> render_click()
    assert %Config{enabled: false} = Store.get("pg")
    assert has_element?(view, "#upstream-pg button", "enable")

    view |> element("#upstream-pg button", "delete") |> render_click()
    refute has_element?(view, "#upstream-pg")
    assert Store.get("pg") == nil
  end

  test "rejects invalid env JSON and invalid configs", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/upstreams")

    assert view
           |> form("#upstream-form",
             config: %{id: "x", command: "cmd", env: "not json", enabled: "true"}
           )
           |> render_submit() =~ "env must be a valid JSON object"

    assert view
           |> form("#upstream-form",
             config: %{id: "Bad_Id", command: "cmd", env: "{}", enabled: "true"}
           )
           |> render_submit() =~ "lowercase"

    assert view
           |> form("#upstream-form",
             config: %{id: "x", command: "cmd", args: "{not json", env: "{}", enabled: "true"}
           )
           |> render_submit() =~ "invalid JSON reference in args"

    assert Store.list() == []
  end
end
