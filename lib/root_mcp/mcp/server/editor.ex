defmodule Root.MCP.Server.Editor do
  @moduledoc """
  The editor-mode MCP server, exposed over Streamable HTTP at `/mcp/editor`.

  Editor sessions manage and inspect the upstream MCP servers loaded into
  Root and will author tool compositions. Client sessions use
  `Root.MCP.Server.Client` at `/mcp` instead and never see these tools.
  """

  use Anubis.Server,
    name: "RootMCP Editor",
    version: "0.1.0",
    capabilities: [:tools],
    instructions: """
    RootMCP editor: compose tools of the loaded upstream MCP servers into new
    reusable tools, implemented as Python scripts that run outside the model.
    Workflow: call composition_guide once to learn the script contract, use
    list_upstreams / list_upstream_tools to see what can be composed, write
    the script, verify it with test_composition (it runs against the live
    upstreams and returns results or tracebacks), then store it with
    upsert_composition.
    """

  component(Root.MCP.Server.Editor.Tools.ListUpstreams)
  component(Root.MCP.Server.Editor.Tools.ListUpstreamTools)
  component(Root.MCP.Server.Editor.Tools.CompositionGuide)
  component(Root.MCP.Server.Editor.Tools.UpsertComposition)
  component(Root.MCP.Server.Editor.Tools.TestComposition)
  component(Root.MCP.Server.Editor.Tools.ListCompositions)
  component(Root.MCP.Server.Editor.Tools.GetComposition)
  component(Root.MCP.Server.Editor.Tools.DeleteComposition)

  @impl true
  def init(_client_info, frame), do: {:ok, frame}
end
