defmodule Root.MCP.Server.Client.Notifier do
  @moduledoc """
  Tells connected client-mode sessions when the tool list changes.

  Subscribes to `Root.Composition.Store` changes and sends
  `notifications/tools/list_changed` to every live session of
  `Root.MCP.Server.Client`, so long-lived clients (e.g. Claude) learn about
  newly authored or deleted compositions without having to re-list on their
  own.
  """

  use GenServer

  alias Anubis.Server.Registry, as: AnubisRegistry
  alias Root.Composition.Store

  @server Root.MCP.Server.Client

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(nil) do
    :ok = Phoenix.PubSub.subscribe(Root.PubSub, Store.topic())
    {:ok, nil}
  end

  @impl true
  def handle_info(:compositions_changed, state) do
    notify_sessions()
    {:noreply, state}
  end

  @spec notify_sessions() :: :ok
  defp notify_sessions do
    supervisor = AnubisRegistry.session_supervisor_name(@server)

    # the session supervisor only exists when the MCP transport is started
    if Process.whereis(supervisor) do
      for {_id, pid, _type, _modules} <- DynamicSupervisor.which_children(supervisor),
          is_pid(pid) do
        send(pid, {:send_notification, "notifications/tools/list_changed", %{}})
      end
    end

    :ok
  end
end
