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
    capabilities: [:tools]

  component(Root.MCP.Server.Editor.Tools.ListUpstreams)

  @impl true
  def init(_client_info, frame), do: {:ok, frame}
end
