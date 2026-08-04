defmodule Root.MCP.Server.Client do
  @moduledoc """
  The client-mode (gateway) MCP server, exposed over Streamable HTTP at `/mcp`.

  Client sessions see the curated gateway tools; editor sessions use
  `Root.MCP.Server.Editor` at `/mcp/editor` instead.

  Register new tools, prompts, and resources by adding `component` entries.
  """

  use Anubis.Server,
    name: "RootMCP",
    version: "0.1.0",
    capabilities: [:tools]

  component(Root.MCP.Server.Client.Tools.Echo)

  @impl true
  def init(_client_info, frame) do
    {:ok, frame}
  end
end
