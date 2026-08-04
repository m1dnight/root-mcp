defmodule Root.MCP.Server.Proxy do
  @moduledoc """
  MCP server that proxies every tool of every running upstream, exposed over
  Streamable HTTP at `/mcp/proxy` behind bearer-token auth
  (`Root.MCP.Server.Proxy.Token`).

  Tools are advertised as `<upstream_id>__<tool_name>` with the exact input
  schema the upstream reported, and calls are delegated to the already-running
  upstream connections — nothing is spawned per request. The tool set follows
  the running upstreams: it is re-snapshotted on every `tools/list` and on any
  `tools/call` naming an unknown tool, so sessions see upstreams added or
  removed after they initialized. (Server-initiated `list_changed`
  notifications are still not sent; long-lived clients notice changes when
  they next list.)

  Composition scripts are the primary clients of this endpoint.
  """

  use Anubis.Server,
    name: "RootMCP Proxy",
    version: "0.1.0",
    capabilities: [:tools]

  alias Anubis.MCP.Error
  alias Anubis.Server.Component.Tool
  alias Anubis.Server.Frame
  alias Anubis.Server.Handlers
  alias Anubis.Server.Response
  alias Root.MCP.Upstream

  @impl true
  def init(_client_info, frame) do
    {:ok, register_upstream_tools(frame)}
  end

  # overrides the injected default (which just calls Handlers.handle/3) to
  # refresh the tool snapshot before Anubis routes tools/* requests
  @impl true
  def handle_request(%{"method" => "tools/" <> _} = request, frame) do
    Handlers.handle(request, __MODULE__, maybe_refresh_tools(request, frame))
  end

  def handle_request(request, frame) do
    Handlers.handle(request, __MODULE__, frame)
  end

  @impl true
  def handle_tool_call(name, params, frame) do
    {id, tool} = Map.fetch!(frame.assigns.proxy_routes, name)

    case Upstream.call_tool(id, tool, params) do
      {:ok, response} ->
        {:reply, to_server_response(response), frame}

      {:error, %Error{} = error} ->
        {:error, error, frame}

      {:error, reason} ->
        {:error, Error.execution("upstream call failed", %{reason: inspect(reason)}), frame}
    end
  end

  # ---------------------------------------------------------------------------#
  #                                Helpers                                     #
  # ---------------------------------------------------------------------------#

  @spec maybe_refresh_tools(Anubis.Server.request(), Frame.t()) :: Frame.t()
  # always refresh tools when the client calls the tool list.
  defp maybe_refresh_tools(%{"method" => "tools/list"}, frame) do
    register_upstream_tools(frame)
  end

  # the tool might not be in the table of available tools, so refresh to be sure.
  defp maybe_refresh_tools(%{"method" => "tools/call", "params" => %{"name" => name}}, frame) do
    if Map.has_key?(Map.get(frame.assigns, :proxy_routes, %{}), name) do
      frame
    else
      register_upstream_tools(frame)
    end
  end

  defp maybe_refresh_tools(_request, frame) do
    frame
  end

  # rebuilds the frame's tool set from the currently running upstreams; the
  # frame's tools are entirely ours (no compile-time components), so replace
  @spec register_upstream_tools(Frame.t()) :: Frame.t()
  defp register_upstream_tools(frame) do
    {tools, routes} =
      for id <- Upstream.list(),
          tool <- upstream_tools(id),
          reduce: {%{}, %{}} do
        {tools, routes} ->
          name = "#{id}__#{tool["name"]}"

          {Map.put(tools, name, build_tool(name, tool)),
           Map.put(routes, name, {id, tool["name"]})}
      end

    %{frame | tools: tools}
    |> Frame.assign(:proxy_routes, routes)
  end

  @spec upstream_tools(Upstream.id()) :: [map()]
  defp upstream_tools(id) do
    case Upstream.list_tools(id) do
      {:ok, %{result: %{"tools" => tools}}} -> tools
      _unavailable -> []
    end
  end

  # built by hand instead of Frame.register_tool/3 because the latter expects
  # Anubis' schema DSL, while upstreams report ready-made JSON Schema
  @spec build_tool(String.t(), map()) :: Tool.t()
  defp build_tool(name, tool) do
    %Tool{
      name: name,
      title: tool["title"] || name,
      description: tool["description"],
      input_schema: tool["inputSchema"] || %{"type" => "object"},
      # the upstream validates its own input
      validate_input: fn params -> {:ok, params} end
    }
  end

  @spec to_server_response(Anubis.MCP.Response.t()) :: Response.t()
  defp to_server_response(%{result: result}) do
    %{Response.tool() | content: result["content"] || [], isError: result["isError"] || false}
  end
end
