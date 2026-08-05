defmodule Root.MCP.Server.Editor.Tools.ListUpstreamTools do
  @moduledoc "Lists the tools of the upstream MCP servers loaded into Root, with their input schemas"

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias Root.MCP.Upstream

  schema do
    field :upstream, :string,
      description: "only list tools of this upstream (default: all upstreams)"
  end

  @impl true
  def execute(params, frame) do
    case Map.get(params, :upstream) do
      nil ->
        reply(Upstream.list(), frame)

      id ->
        if id in Upstream.list() do
          reply([id], frame)
        else
          {:reply, Response.error(Response.tool(), "no such upstream: #{id}"), frame}
        end
    end
  end

  @spec reply([Upstream.id()], Anubis.Server.Frame.t()) ::
          {:reply, Response.t(), Anubis.Server.Frame.t()}
  defp reply(ids, frame) do
    upstreams = for id <- ids, do: %{id: id, tools: tools_of(id)}
    {:reply, Response.json(Response.tool(), %{upstreams: upstreams}), frame}
  end

  @spec tools_of(Upstream.id()) :: [map()]
  defp tools_of(id) do
    case Upstream.list_tools(id) do
      {:ok, %{result: %{"tools" => tools}}} ->
        Enum.map(tools, &Map.take(&1, ["name", "title", "description", "inputSchema"]))

      _unavailable ->
        []
    end
  end
end
