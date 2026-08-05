defmodule Root.MCP.Server.Editor.Tools.UpsertComposition do
  @moduledoc "Creates or updates a composition: a Python script stored as a reusable tool. Follow composition_guide for the script contract"

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias Root.Composition
  alias Root.Composition.Store

  schema do
    field :name, :string,
      required: true,
      description:
        "tool name, lowercase snake_case; an existing composition of this name is replaced"

    field :description, :string,
      required: true,
      description: "what the composed tool does, written for the LLM that will use it"

    field :input_schema, :map,
      description: "JSON Schema of the tool's input object (default: no inputs)"

    field :code, :string,
      required: true,
      description: "the Python script; must define run(args), see composition_guide"
  end

  @impl true
  def execute(params, frame) do
    # an update must not re-enable a composition the user disabled
    params = Map.put(params, :enabled, currently_enabled?(params[:name]))

    case Composition.new(params) do
      {:ok, composition} ->
        :ok = Store.put(composition)
        {:reply, Response.json(Response.tool(), %{stored: composition.name}), frame}

      {:error, message} ->
        {:reply, Response.error(Response.tool(), message), frame}
    end
  end

  @spec currently_enabled?(String.t() | nil) :: boolean()
  defp currently_enabled?(name) when is_binary(name) do
    case Store.get(name) do
      nil -> true
      composition -> composition.enabled
    end
  end

  defp currently_enabled?(_name), do: true
end
