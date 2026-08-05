defmodule Root.MCP.Server.Editor.Tools.GetComposition do
  @moduledoc "Returns a stored composition in full: description, input schema, and code"

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias Root.Composition.Store

  schema do
    field :name, :string, required: true, description: "name of the composition"
  end

  @impl true
  def execute(%{name: name}, frame) do
    case Store.get(name) do
      nil ->
        {:reply, Response.error(Response.tool(), "no such composition: #{name}"), frame}

      composition ->
        {:reply,
         Response.json(Response.tool(), %{
           name: composition.name,
           description: composition.description,
           input_schema: composition.input_schema,
           code: composition.code
         }), frame}
    end
  end
end
