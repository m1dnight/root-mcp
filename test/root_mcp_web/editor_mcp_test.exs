defmodule RootWeb.EditorMCPTest do
  use RootWeb.ConnCase, async: false

  import RootWeb.MCPHelpers

  alias Root.MCP.Upstream

  @fixture Path.expand("../support/fixtures/stdio_echo_server.exs", __DIR__)

  test "initialize returns editor server info" do
    {response, _session_id} = initialize_mcp("/mcp/editor")

    assert %{"result" => %{"serverInfo" => %{"name" => "RootMCP Editor"}}} = response
  end

  test "exposes list_upstreams and reflects running upstreams" do
    {_response, session_id} = initialize_mcp("/mcp/editor")

    assert %{"result" => %{"tools" => [%{"name" => "list_upstreams"}]}} =
             mcp_request("/mcp/editor", session_id, 2, "tools/list")

    assert %{"upstreams" => []} =
             mcp_call_tool("/mcp/editor", session_id, 3, "list_upstreams")

    {:ok, _pid} = Upstream.start("editor-echo", command: "elixir", args: [@fixture])
    on_exit(fn -> Upstream.stop("editor-echo") end)
    :ok = Upstream.await_ready("editor-echo", timeout: 15_000)

    assert %{"upstreams" => [%{"id" => "editor-echo", "server" => %{"name" => "stdio-echo"}}]} =
             mcp_call_tool("/mcp/editor", session_id, 4, "list_upstreams")
  end
end
