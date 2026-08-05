defmodule Root.MCP.Server.Client do
  @moduledoc """
  The client-mode (gateway) MCP server, exposed over Streamable HTTP at `/mcp`.

  Serves the stored compositions as plain tools: each composition is
  advertised under its name with its declared input schema, and executed by
  `Root.Composition.Runner` when called — the caller never sees Python or
  upstreams. The tool set follows the store: it is re-snapshotted on every
  `tools/list` and on any `tools/call` naming an unknown tool, so
  compositions authored in a live editor session become callable
  immediately.

  Compositions are authored through `Root.MCP.Server.Editor` at
  `/mcp/editor`; none of those tools are exposed here.
  """

  use Anubis.Server,
    name: "RootMCP",
    version: "0.1.0",
    capabilities: [{:tools, list_changed?: true}]

  alias Anubis.MCP.Error
  alias Anubis.Server.Component.Tool
  alias Anubis.Server.Frame
  alias Anubis.Server.Handlers
  alias Anubis.Server.Response
  alias Root.Composition
  alias Root.Composition.Runner
  alias Root.Composition.Store

  @impl true
  def init(_client_info, frame) do
    {:ok, register_composition_tools(frame)}
  end

  # overrides the injected default (which just calls Handlers.handle/3) to
  # refresh the tool snapshot before Anubis routes tools/* requests
  @impl true
  def handle_request(%{"method" => "tools/" <> _} = request, frame) do
    Handlers.handle(request, __MODULE__, maybe_refresh_tools(request, frame))
  end

  def handle_request(request, frame), do: Handlers.handle(request, __MODULE__, frame)

  @impl true
  def handle_tool_call(name, params, frame) do
    case Store.get(name) do
      %Composition{code: code} ->
        {:reply, run(code, params), frame}

      nil ->
        {:error, Error.protocol(:method_not_found, %{message: "no such composition: #{name}"}),
         frame}
    end
  end

  @spec run(String.t(), map()) :: Response.t()
  defp run(code, args) do
    case Runner.run(code, args) do
      {:ok, result} -> Response.json(Response.tool(), result)
      {:error, reason} -> Response.error(Response.tool(), Runner.describe_error(reason))
    end
  end

  @spec maybe_refresh_tools(Anubis.Server.request(), Frame.t()) :: Frame.t()
  defp maybe_refresh_tools(%{"method" => "tools/list"}, frame) do
    register_composition_tools(frame)
  end

  defp maybe_refresh_tools(%{"method" => "tools/call", "params" => %{"name" => name}}, frame) do
    if Map.has_key?(frame.tools, name) do
      frame
    else
      register_composition_tools(frame)
    end
  end

  defp maybe_refresh_tools(_request, frame), do: frame

  # rebuilds the frame's tool set from the store; the frame's tools are
  # entirely ours (no compile-time components), so replace
  @spec register_composition_tools(Frame.t()) :: Frame.t()
  defp register_composition_tools(frame) do
    tools =
      for composition <- Store.list(), into: %{} do
        {composition.name, build_tool(composition)}
      end

    %{frame | tools: tools}
  end

  # built by hand instead of Frame.register_tool/3 because the latter expects
  # Anubis' schema DSL, while compositions declare ready-made JSON Schema
  @spec build_tool(Composition.t()) :: Tool.t()
  defp build_tool(%Composition{} = composition) do
    %Tool{
      name: composition.name,
      title: composition.name,
      description: composition.description,
      input_schema: composition.input_schema,
      # the declared schema is advertised to clients; the script itself is
      # the authority on its input
      validate_input: fn params -> {:ok, params} end
    }
  end
end
