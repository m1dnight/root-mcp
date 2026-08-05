defmodule Root.MCP.Server.Editor.Tools.DeleteComposition do
  @moduledoc "Deletes a stored composition"

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias Root.Composition.Store

  schema do
    field :name, :string, required: true, description: "name of the composition to delete"
  end

  @impl true
  def execute(%{name: name}, frame) do
    case Store.delete(name) do
      :ok ->
        {:reply, Response.json(Response.tool(), %{deleted: name}), frame}

      {:error, :not_found} ->
        {:reply, Response.error(Response.tool(), "no such composition: #{name}"), frame}
    end
  end
end
