defmodule Root.MCP.Server.Editor.Tools.ListCompositions do
  @moduledoc "Lists the stored compositions (name and description; use get_composition for the code)"

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias Root.Composition.Store

  schema do
  end

  @impl true
  def execute(_params, frame) do
    compositions =
      for composition <- Store.list() do
        %{name: composition.name, description: composition.description}
      end

    {:reply, Response.json(Response.tool(), %{compositions: compositions}), frame}
  end
end
