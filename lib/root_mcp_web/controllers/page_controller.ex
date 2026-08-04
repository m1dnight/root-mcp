defmodule RootWeb.PageController do
  use RootWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
