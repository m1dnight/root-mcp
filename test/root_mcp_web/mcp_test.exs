defmodule RootWeb.MCPTest do
  use RootWeb.ConnCase, async: false

  import RootWeb.MCPHelpers

  test "initialize returns server info" do
    {response, _session_id} = initialize_mcp("/mcp")

    assert %{"result" => %{"serverInfo" => %{"name" => "RootMCP"}}} = response
  end

  test "lists and calls the echo tool" do
    {_response, session_id} = initialize_mcp("/mcp")

    assert %{"result" => %{"tools" => [%{"name" => "echo"}]}} =
             mcp_request("/mcp", session_id, 2, "tools/list")

    assert %{"result" => %{"content" => [%{"type" => "text", "text" => "hello"}]}} =
             mcp_request("/mcp", session_id, 3, "tools/call", %{
               "name" => "echo",
               "arguments" => %{"text" => "hello"}
             })
  end
end
