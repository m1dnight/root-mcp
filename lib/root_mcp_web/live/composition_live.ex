defmodule RootWeb.CompositionLive do
  @moduledoc "Read-only browser for stored compositions."

  use RootWeb, :live_view

  alias Root.Composition.Store
  alias RootWeb.PythonHighlighter

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Root.PubSub, Store.topic())
    end

    {:ok, assign(socket, compositions: Store.list(), page_title: "Compositions")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    selected = if name = params["name"], do: Store.get(name)
    {:noreply, assign(socket, :selected, selected)}
  end

  @impl true
  def handle_info(:compositions_changed, socket) do
    selected = if current = socket.assigns.selected, do: Store.get(current.name)

    {:noreply, assign(socket, compositions: Store.list(), selected: selected)}
  end
end
