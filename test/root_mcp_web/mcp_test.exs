defmodule RootWeb.MCPTest do
  use RootWeb.ConnCase, async: false

  @protocol_version "2025-06-18"

  defp post_mcp(conn, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post(~p"/mcp", body)
  end

  defp initialize(conn) do
    conn =
      post_mcp(conn, %{
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

    build_conn()
    |> put_req_header("mcp-session-id", session_id)
    |> put_req_header("mcp-protocol-version", @protocol_version)
    |> post_mcp(%{"jsonrpc" => "2.0", "method" => "notifications/initialized"})

    {json_response(conn, 200), session_id}
  end

  defp request(session_id, id, method, params) do
    build_conn()
    |> put_req_header("mcp-session-id", session_id)
    |> put_req_header("mcp-protocol-version", @protocol_version)
    |> post_mcp(%{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params})
    |> json_response(200)
  end

  test "initialize returns server info", %{conn: conn} do
    {response, _session_id} = initialize(conn)

    assert %{"result" => %{"serverInfo" => %{"name" => "RootMCP"}}} = response
  end

  test "lists and calls the echo tool", %{conn: conn} do
    {_response, session_id} = initialize(conn)

    assert %{"result" => %{"tools" => [%{"name" => "echo"}]}} =
             request(session_id, 2, "tools/list", %{})

    assert %{"result" => %{"content" => [%{"type" => "text", "text" => "hello"}]}} =
             request(session_id, 3, "tools/call", %{
               "name" => "echo",
               "arguments" => %{"text" => "hello"}
             })
  end
end
