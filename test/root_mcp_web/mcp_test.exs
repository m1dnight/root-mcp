defmodule RootWeb.MCPTest do
  use RootWeb.ConnCase, async: false

  # store changes notify idle test sessions, which log no_sse_handler errors
  @moduletag :capture_log

  import RootWeb.MCPHelpers

  alias Root.Composition
  alias Root.Composition.Store

  defp store_composition(name, code, schema \\ %{"type" => "object"}) do
    {:ok, composition} =
      Composition.new(%{
        name: name,
        description: "test composition",
        input_schema: schema,
        code: code
      })

    :ok = Store.put(composition)
    on_exit(fn -> Store.delete(name) end)
  end

  test "initialize returns server info and advertises listChanged" do
    {response, _session_id} = initialize_mcp("/mcp")

    assert %{
             "result" => %{
               "serverInfo" => %{"name" => "RootMCP"},
               "capabilities" => %{"tools" => %{"listChanged" => true}}
             }
           } = response
  end

  # regression: the router's :api pipeline (accepts ["json"]) used to 406 the
  # SSE GET stream, so server-initiated notifications never reached clients
  test "the SSE notification stream can be opened" do
    {_response, session_id} = initialize_mcp("/mcp")

    port = URI.parse(RootWeb.Endpoint.url()).port
    {:ok, socket} = :gen_tcp.connect(~c"localhost", port, [:binary, active: false])

    request =
      "GET /mcp HTTP/1.1\r\nhost: localhost\r\naccept: text/event-stream\r\n" <>
        "mcp-session-id: #{session_id}\r\nmcp-protocol-version: 2025-06-18\r\n\r\n"

    :ok = :gen_tcp.send(socket, request)
    {:ok, response} = :gen_tcp.recv(socket, 0, 5000)

    assert response =~ "HTTP/1.1 200"
    assert response =~ "text/event-stream"

    :gen_tcp.close(socket)
  end

  test "store changes push tools/list_changed to live sessions" do
    {_response, session_id} = initialize_mcp("/mcp")

    config = Anubis.Server.Supervisor.get_session_config(Root.MCP.Server.Client)
    registry_name = Anubis.Server.Registry.registry_name(Root.MCP.Server.Client)
    {:ok, session_pid} = config.registry_mod.lookup_session(registry_name, session_id)

    :erlang.trace(session_pid, true, [:receive])

    on_exit(fn ->
      # the session may already be gone by then; tracing a dead pid raises
      try do
        :erlang.trace(session_pid, false, [:receive])
      rescue
        ArgumentError -> :ok
      end
    end)

    store_composition("noisy", "def run(args):\n    return {}")

    assert_receive {:trace, ^session_pid, :receive,
                    {:send_notification, "notifications/tools/list_changed", %{}}},
                   2000
  end

  test "serves stored compositions as tools, following the store" do
    {_response, session_id} = initialize_mcp("/mcp")

    assert %{"result" => %{"tools" => []}} = mcp_request("/mcp", session_id, 2, "tools/list")

    store_composition(
      "double",
      "def run(args):\n    return {\"doubled\": args[\"n\"] * 2}",
      %{
        "type" => "object",
        "properties" => %{"n" => %{"type" => "number"}},
        "required" => ["n"]
      }
    )

    # calling before re-listing proves the refresh-on-unknown-tool path
    assert %{"doubled" => 12} = mcp_call_tool("/mcp", session_id, 3, "double", %{"n" => 6})

    assert %{"result" => %{"tools" => [tool]}} = mcp_request("/mcp", session_id, 4, "tools/list")

    assert %{
             "name" => "double",
             "description" => "test composition",
             "inputSchema" => %{"properties" => %{"n" => _}}
           } = tool

    :ok = Store.delete("double")
    assert %{"result" => %{"tools" => []}} = mcp_request("/mcp", session_id, 5, "tools/list")
  end

  test "script failures surface as tool errors" do
    store_composition("boom", "def run(args):\n    raise RuntimeError(\"bad\")")
    {_response, session_id} = initialize_mcp("/mcp")

    assert %{"result" => %{"isError" => true, "content" => [%{"text" => failure}]}} =
             mcp_request("/mcp", session_id, 2, "tools/call", %{
               "name" => "boom",
               "arguments" => %{}
             })

    assert failure =~ "RuntimeError: bad"
  end

  test "a composition authored in editor mode is callable in user mode" do
    on_exit(fn -> Store.delete("greet") end)

    {_response, editor_session} = initialize_mcp("/mcp/editor")

    assert %{"stored" => "greet"} =
             mcp_call_tool("/mcp/editor", editor_session, 2, "upsert_composition", %{
               "name" => "greet",
               "description" => "Greets someone by name",
               "input_schema" => %{
                 "type" => "object",
                 "properties" => %{"who" => %{"type" => "string"}},
                 "required" => ["who"]
               },
               "code" => "def run(args):\n    return {\"greeting\": \"hi \" + args[\"who\"]}"
             })

    {_response, user_session} = initialize_mcp("/mcp")

    assert %{"greeting" => "hi zoe"} =
             mcp_call_tool("/mcp", user_session, 2, "greet", %{"who" => "zoe"})
  end
end
