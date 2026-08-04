defmodule RootWeb.MCPHelpers do
  @moduledoc """
  Drives the MCP Streamable HTTP protocol against an endpoint path in tests.
  """

  import Phoenix.ConnTest
  import Plug.Conn

  @endpoint RootWeb.Endpoint
  @protocol_version "2025-06-18"

  @doc "Performs the initialize handshake. Returns `{response, session_id}`."
  def initialize_mcp(path) do
    conn =
      post_mcp(path, %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => @protocol_version,
          "capabilities" => %{},
          "clientInfo" => %{"name" => "test-client", "version" => "0.0.0"}
        }
      })

    [session_id] = get_resp_header(conn, "mcp-session-id")

    post_mcp(path, %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}, session_id)

    {json_response(conn, 200), session_id}
  end

  @doc "Sends a request on an initialized session and returns the decoded response."
  def mcp_request(path, session_id, id, method, params \\ %{}) do
    path
    |> post_mcp(
      %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params},
      session_id
    )
    |> json_response(200)
  end

  @doc "Calls a tool on an initialized session and returns its decoded JSON text content."
  def mcp_call_tool(path, session_id, id, tool, arguments \\ %{}) do
    params = %{"name" => tool, "arguments" => arguments}

    %{"result" => %{"content" => [%{"type" => "text", "text" => text}]}} =
      mcp_request(path, session_id, id, "tools/call", params)

    JSON.decode!(text)
  end

  defp post_mcp(path, body, session_id \\ nil) do
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> put_session_headers(session_id)
    |> post(path, body)
  end

  defp put_session_headers(conn, nil), do: conn

  defp put_session_headers(conn, session_id) do
    conn
    |> put_req_header("mcp-session-id", session_id)
    |> put_req_header("mcp-protocol-version", @protocol_version)
  end
end
