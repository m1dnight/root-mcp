defmodule Root.MCP.Server.Editor.Tools.CompositionGuide do
  @moduledoc "Returns the guide for writing composition scripts. Read this before writing one."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response

  @guide """
  # Writing RootMCP composition scripts

  A composition is ONE Python script that chains upstream tools into a single
  reusable tool. It runs outside the model in a subprocess: once written, it
  executes deterministically and costs no tokens.

  ## Contract

  - Define `run(args)` as the entry point. `args` is a dict matching the
    composition's declared input schema.
  - Return a JSON-serializable value (dict recommended). The return value is
    the composed tool's result.
  - Python 3 standard library only — no third-party imports, no pip.
  - Call upstream tools ONLY through the `root` helper (see below). Do not
    use HTTP libraries directly; the environment provides the connection.
  - `print()` output goes to stderr and is shown for debugging; it cannot
    corrupt the result. Never print your result — return it.
  - Raise exceptions freely on unrecoverable errors: the traceback is
    reported back to the caller.
  - Default execution deadline is 30 seconds.

  ## The root helper

      from root import call_tool, text

  - `call_tool(upstream_id, tool_name, arguments_dict)` — calls one upstream
    tool. Returns the MCP result dict: `{"content": [...], "isError": bool}`.
    Raises `root.ToolError` if the call fails or the tool reports an error.
  - `text(result)` — concatenated text of a result's text content blocks.
    Most tools return their payload this way; parse it as needed.

  Use `list_upstream_tools` first to see upstream ids, tool names, and exact
  input schemas. Tool OUTPUT formats are not declared — when unsure, keep the
  parsing defensive.

  ## Template

      from root import call_tool, text

      def run(args):
          found = text(call_tool("fs1", "search_files", {
              "path": args["directory"],
              "pattern": args["pattern"],
          }))
          paths = [p for p in found.splitlines() if p.strip()]
          contents = {
              p: text(call_tool("fs1", "read_text_file", {"path": p}))
              for p in paths
          }
          return {"matches": len(paths), "contents": contents}

  Helper functions besides `run` are fine. Code at module top level runs at
  import time — keep it to imports and constants.

  ## Testing and storing

  Verify scripts with `test_composition` — it executes them against the live
  upstreams and returns the result, or the Python traceback on failure. Pass
  `code` while iterating; store the finished script with `upsert_composition`
  (name, a description written for the LLM that will use the tool, a JSON
  Schema for its input), then run it once more via its `name` to confirm the
  stored version.
  """

  schema do
  end

  @impl true
  def execute(_params, frame) do
    {:reply, Response.text(Response.tool(), @guide), frame}
  end
end
