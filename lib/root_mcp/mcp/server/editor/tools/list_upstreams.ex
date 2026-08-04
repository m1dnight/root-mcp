defmodule Root.MCP.Server.Editor.Tools.ListUpstreams do
  @moduledoc "Lists the upstream MCP servers currently loaded into Root"

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias Root.MCP.Upstream

  schema do
  end

  @impl true
  def execute(_params, frame) do
    upstreams =
      for id <- Upstream.list() do
        case Upstream.server_info(id) do
          %{} = info -> %{id: id, server: info}
          _not_ready -> %{id: id, server: nil}
        end
      end

    {:reply, Response.json(Response.tool(), %{upstreams: upstreams}), frame}
  end
end
