defmodule Root.MCP.Server.Client.Tools.Echo do
  @moduledoc "Echoes the given text back to the caller"

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response

  schema do
    field :text, :string, required: true, description: "the text to be echoed"
  end

  @impl true
  def execute(%{text: text}, frame) do
    {:reply, Response.text(Response.tool(), text), frame}
  end
end
