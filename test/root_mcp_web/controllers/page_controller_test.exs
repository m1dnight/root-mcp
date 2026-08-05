defmodule RootWeb.PageControllerTest do
  use RootWeb.ConnCase, async: true

  test "GET / redirects to the compositions browser", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/compositions"
  end
end
