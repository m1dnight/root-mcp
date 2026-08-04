defmodule Root.MCP.Server do
  @moduledoc """
  The MCP server for RootMCP, exposed over Streamable HTTP at `/mcp`.

  Register new tools, prompts, and resources by adding `component` entries.
  """

  use Anubis.Server,
    name: "RootMCP",
    version: "0.1.0",
    capabilities: [:tools]

  component(Root.MCP.Tools.Echo)

  @impl true
  def init(_client_info, frame) do
    {:ok, frame}
  end
end
