defmodule RootWeb.ProxyMCPTest do
  use RootWeb.ConnCase, async: false

  import RootWeb.MCPHelpers

  alias Root.MCP.Server.Proxy.Token
  alias Root.MCP.Upstream

  @fixture Path.expand("../support/fixtures/stdio_echo_server.exs", __DIR__)

  test "rejects requests without a valid bearer token", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json")
      |> post("/mcp/proxy", %{})

    assert %{"error" => _} = json_response(conn, 401)
  end

  test "accepts a configured static token" do
    Application.put_env(:root_mcp, :proxy_static_token, "static-test-token")
    on_exit(fn -> Application.delete_env(:root_mcp, :proxy_static_token) end)

    assert {%{"result" => %{"serverInfo" => _}}, _session_id} =
             initialize_mcp("/mcp/proxy", bearer: "static-test-token")
  end

  test "advertises no tools when no upstreams run" do
    bearer = Token.mint()
    {_response, session_id} = initialize_mcp("/mcp/proxy", bearer: bearer)

    assert %{"result" => %{"tools" => []}} =
             mcp_request("/mcp/proxy", session_id, 2, "tools/list", %{}, bearer: bearer)
  end

  test "picks up upstreams started and stopped after the session initialized" do
    bearer = Token.mint()
    {_response, session_id} = initialize_mcp("/mcp/proxy", bearer: bearer)

    assert %{"result" => %{"tools" => []}} =
             mcp_request("/mcp/proxy", session_id, 2, "tools/list", %{}, bearer: bearer)

    {:ok, _pid} = Upstream.start("late", command: "elixir", args: [@fixture])
    on_exit(fn -> Upstream.stop("late") end)
    :ok = Upstream.await_ready("late", timeout: 15_000)

    # calling before re-listing proves the refresh-on-unknown-tool path
    assert %{"result" => %{"content" => [%{"type" => "text", "text" => "dyn"}]}} =
             mcp_request(
               "/mcp/proxy",
               session_id,
               3,
               "tools/call",
               %{"name" => "late__echo", "arguments" => %{"text" => "dyn"}},
               bearer: bearer
             )

    assert %{"result" => %{"tools" => [%{"name" => "late__echo"}]}} =
             mcp_request("/mcp/proxy", session_id, 4, "tools/list", %{}, bearer: bearer)

    :ok = Upstream.stop("late")

    assert %{"result" => %{"tools" => []}} =
             mcp_request("/mcp/proxy", session_id, 5, "tools/list", %{}, bearer: bearer)
  end

  test "proxies upstream tools with their schemas and forwards calls" do
    {:ok, _pid} = Upstream.start("prox", command: "elixir", args: [@fixture])
    on_exit(fn -> Upstream.stop("prox") end)
    :ok = Upstream.await_ready("prox", timeout: 15_000)

    bearer = Token.mint(%{"exec" => "test-run"})

    {response, session_id} = initialize_mcp("/mcp/proxy", bearer: bearer)
    assert %{"result" => %{"serverInfo" => %{"name" => "RootMCP Proxy"}}} = response

    assert %{"result" => %{"tools" => [tool]}} =
             mcp_request("/mcp/proxy", session_id, 2, "tools/list", %{}, bearer: bearer)

    assert %{"name" => "prox__echo", "inputSchema" => %{"properties" => %{"text" => _}}} = tool

    assert %{"result" => %{"content" => [%{"type" => "text", "text" => "hi"}]}} =
             mcp_request(
               "/mcp/proxy",
               session_id,
               3,
               "tools/call",
               %{"name" => "prox__echo", "arguments" => %{"text" => "hi"}},
               bearer: bearer
             )
  end
end
