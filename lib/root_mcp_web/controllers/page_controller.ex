defmodule RootWeb.PageController do
  use RootWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/compositions")
  end
end
