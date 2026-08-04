defmodule RootWeb.Plugs.ProxyAuth do
  @moduledoc """
  Requires a valid proxy bearer token (`Root.MCP.Server.Proxy.Token`) on
  every request, rejecting with 401 otherwise.
  """

  @behaviour Plug

  import Plug.Conn

  alias Root.MCP.Server.Proxy.Token

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, meta} <- Token.verify(token) do
      assign(conn, :proxy_token, meta)
    else
      _missing_or_invalid ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, JSON.encode!(%{"error" => "invalid or missing bearer token"}))
        |> halt()
    end
  end
end
