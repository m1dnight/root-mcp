defmodule RootWeb.EditorMCPTest do
  use RootWeb.ConnCase, async: false

  # composition upserts notify idle test sessions, which log no_sse_handler errors
  @moduletag :capture_log

  import RootWeb.MCPHelpers

  alias Root.MCP.Upstream

  @fixture Path.expand("../support/fixtures/stdio_echo_server.exs", __DIR__)

  test "initialize returns editor server info" do
    {response, _session_id} = initialize_mcp("/mcp/editor")

    assert %{"result" => %{"serverInfo" => %{"name" => "RootMCP Editor"}}} = response
  end

  test "exposes list_upstreams and reflects running upstreams" do
    {_response, session_id} = initialize_mcp("/mcp/editor")

    assert %{"result" => %{"tools" => tools}} =
             mcp_request("/mcp/editor", session_id, 2, "tools/list")

    assert Enum.map(tools, & &1["name"]) == [
             "composition_guide",
             "delete_composition",
             "get_composition",
             "list_compositions",
             "list_upstream_tools",
             "list_upstreams",
             "test_composition",
             "upsert_composition"
           ]

    assert %{"upstreams" => []} =
             mcp_call_tool("/mcp/editor", session_id, 3, "list_upstreams")

    {:ok, _pid} = Upstream.start("editor-echo", command: "elixir", args: [@fixture])
    on_exit(fn -> Upstream.stop("editor-echo") end)
    :ok = Upstream.await_ready("editor-echo", timeout: 15_000)

    assert %{"upstreams" => [%{"id" => "editor-echo", "server" => %{"name" => "stdio-echo"}}]} =
             mcp_call_tool("/mcp/editor", session_id, 4, "list_upstreams")
  end

  test "composition_guide returns the authoring contract" do
    {_response, session_id} = initialize_mcp("/mcp/editor")

    assert %{"result" => %{"content" => [%{"type" => "text", "text" => guide}]}} =
             mcp_request("/mcp/editor", session_id, 2, "tools/call", %{
               "name" => "composition_guide",
               "arguments" => %{}
             })

    assert guide =~ "def run(args)"
    assert guide =~ "from root import call_tool, text"
  end

  test "upsert_composition stores a composition and rejects invalid ones" do
    on_exit(fn -> Root.Composition.Store.delete("greet") end)
    {_response, session_id} = initialize_mcp("/mcp/editor")

    assert %{"stored" => "greet"} =
             mcp_call_tool("/mcp/editor", session_id, 2, "upsert_composition", %{
               "name" => "greet",
               "description" => "Greets someone by name",
               "input_schema" => %{
                 "type" => "object",
                 "properties" => %{"who" => %{"type" => "string"}},
                 "required" => ["who"]
               },
               "code" => "def run(args):\n    return {\"greeting\": \"hi \" + args[\"who\"]}"
             })

    assert %Root.Composition{description: "Greets someone by name"} =
             Root.Composition.Store.get("greet")

    assert %{"result" => %{"isError" => true, "content" => [%{"text" => message}]}} =
             mcp_request("/mcp/editor", session_id, 3, "tools/call", %{
               "name" => "upsert_composition",
               "arguments" => %{
                 "name" => "greet",
                 "description" => "broken",
                 "code" => "no entry point here"
               }
             })

    assert message =~ "def run(args)"
  end

  test "test_composition runs inline code and reports tracebacks" do
    {_response, session_id} = initialize_mcp("/mcp/editor")

    assert %{"result" => %{"doubled" => 42}} =
             mcp_call_tool("/mcp/editor", session_id, 2, "test_composition", %{
               "code" => "def run(args):\n    return {\"doubled\": args[\"n\"] * 2}",
               "args" => %{"n" => 21}
             })

    assert %{"result" => %{"isError" => true, "content" => [%{"text" => failure}]}} =
             mcp_request("/mcp/editor", session_id, 3, "tools/call", %{
               "name" => "test_composition",
               "arguments" => %{"code" => "def run(args):\n    raise ValueError(\"nope\")"}
             })

    assert failure =~ "ValueError: nope"

    assert %{
             "result" => %{
               "isError" => true,
               "content" => [%{"text" => "pass either name or code"}]
             }
           } =
             mcp_request("/mcp/editor", session_id, 4, "tools/call", %{
               "name" => "test_composition",
               "arguments" => %{}
             })
  end

  test "the full authoring loop: upsert, test stored, list, get, delete" do
    {:ok, _pid} = Upstream.start("loop-echo", command: "elixir", args: [@fixture])
    on_exit(fn -> Upstream.stop("loop-echo") end)
    on_exit(fn -> Root.Composition.Store.delete("shout") end)
    :ok = Upstream.await_ready("loop-echo", timeout: 15_000)

    {_response, session_id} = initialize_mcp("/mcp/editor")

    code = """
    from root import call_tool, text

    def run(args):
        echoed = text(call_tool("loop-echo", "echo", {"text": args["msg"]}))
        return {"shouted": echoed.upper() + "!"}
    """

    assert %{"stored" => "shout"} =
             mcp_call_tool("/mcp/editor", session_id, 2, "upsert_composition", %{
               "name" => "shout",
               "description" => "Echoes a message and shouts it back",
               "input_schema" => %{
                 "type" => "object",
                 "properties" => %{"msg" => %{"type" => "string"}},
                 "required" => ["msg"]
               },
               "code" => code
             })

    assert %{"result" => %{"shouted" => "HEY!"}} =
             mcp_call_tool("/mcp/editor", session_id, 3, "test_composition", %{
               "name" => "shout",
               "args" => %{"msg" => "hey"}
             })

    assert %{"compositions" => [%{"name" => "shout"}]} =
             mcp_call_tool("/mcp/editor", session_id, 4, "list_compositions")

    assert %{"name" => "shout", "code" => ^code} =
             mcp_call_tool("/mcp/editor", session_id, 5, "get_composition", %{"name" => "shout"})

    assert %{"deleted" => "shout"} =
             mcp_call_tool("/mcp/editor", session_id, 6, "delete_composition", %{
               "name" => "shout"
             })

    assert %{"result" => %{"isError" => true}} =
             mcp_request("/mcp/editor", session_id, 7, "tools/call", %{
               "name" => "test_composition",
               "arguments" => %{"name" => "shout"}
             })
  end

  test "list_upstream_tools returns tool names and schemas" do
    {:ok, _pid} = Upstream.start("editor-tools", command: "elixir", args: [@fixture])
    on_exit(fn -> Upstream.stop("editor-tools") end)
    :ok = Upstream.await_ready("editor-tools", timeout: 15_000)

    {_response, session_id} = initialize_mcp("/mcp/editor")

    assert %{
             "upstreams" => [
               %{
                 "id" => "editor-tools",
                 "tools" => [
                   %{"name" => "echo", "inputSchema" => %{"properties" => %{"text" => _}}}
                 ]
               }
             ]
           } = mcp_call_tool("/mcp/editor", session_id, 2, "list_upstream_tools")

    assert %{"upstreams" => [%{"id" => "editor-tools"}]} =
             mcp_call_tool("/mcp/editor", session_id, 3, "list_upstream_tools", %{
               "upstream" => "editor-tools"
             })

    assert %{
             "result" => %{
               "isError" => true,
               "content" => [%{"text" => "no such upstream: nope"}]
             }
           } =
             mcp_request("/mcp/editor", session_id, 4, "tools/call", %{
               "name" => "list_upstream_tools",
               "arguments" => %{"upstream" => "nope"}
             })
  end
end
