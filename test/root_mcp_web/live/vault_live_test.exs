defmodule RootWeb.VaultLiveTest do
  use RootWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Root.Vault

  test "adds, lists, and deletes secrets without ever showing values", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/vault")

    view
    |> form("#secret-form", secret: %{name: "db-url", value: "postgresql://hunter2@host/db"})
    |> render_submit()

    assert has_element?(view, "#secret-db-url")
    refute render(view) =~ "hunter2"
    assert {:ok, "postgresql://hunter2@host/db"} = Vault.fetch("db-url")

    # same name overwrites
    view
    |> form("#secret-form", secret: %{name: "db-url", value: "rotated"})
    |> render_submit()

    assert {:ok, "rotated"} = Vault.fetch("db-url")

    view
    |> element("#secret-db-url button")
    |> render_click()

    refute has_element?(view, "#secret-db-url")
    assert Vault.fetch("db-url") == :error
  end

  test "rejects empty names and values", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/vault")

    assert view
           |> form("#secret-form", secret: %{name: "  ", value: "x"})
           |> render_submit() =~ "Name must not be empty"

    assert view
           |> form("#secret-form", secret: %{name: "k", value: ""})
           |> render_submit() =~ "Value must not be empty"

    assert Vault.list() == []
  end
end
