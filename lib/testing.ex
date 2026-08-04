defmodule Testing do
  def load do
    Root.MCP.Upstream.start("server-everything",
      command: "npx",
      args: ["-y", "@modelcontextprotocol/server-everything"]
    )

    Root.MCP.Upstream.start("fs",
      command: "npx",
      args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    )
  end
end
