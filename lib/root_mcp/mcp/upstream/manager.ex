defmodule Root.MCP.Upstream.Manager do
  @moduledoc """
  Keeps the running upstreams in sync with the enabled persisted configs.

  On boot it starts every enabled config; afterwards it reacts to config
  store changes (via PubSub): newly enabled configs are started, disabled
  or deleted ones are stopped. It only ever stops upstreams it manages —
  ad-hoc `Root.MCP.Upstream.start/2` upstreams are left alone.

  Disabled entirely with `config :root_mcp, :autostart_upstreams, false`
  (as in the test env, where tests drive upstreams themselves).
  """

  use GenServer

  require Logger

  alias Root.MCP.Upstream
  alias Root.MCP.Upstream.Config

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    enabled? =
      Keyword.get(opts, :enabled, Application.get_env(:root_mcp, :autostart_upstreams, true))

    if enabled? do
      :ok = Phoenix.PubSub.subscribe(Root.PubSub, Config.Store.topic())
      {:ok, %{managed: MapSet.new()}, {:continue, :sync}}
    else
      :ignore
    end
  end

  @impl true
  def handle_continue(:sync, state), do: {:noreply, sync(state)}

  @impl true
  def handle_info(:upstream_configs_changed, state), do: {:noreply, sync(state)}

  @spec sync(%{managed: MapSet.t()}) :: %{managed: MapSet.t()}
  defp sync(%{managed: managed} = state) do
    desired = Config.Store.list_enabled()
    desired_ids = MapSet.new(desired, & &1.id)
    running = MapSet.new(Upstream.list())

    for config <- desired, not MapSet.member?(running, config.id) do
      start_upstream(config)
    end

    for id <- managed, MapSet.member?(running, id), not MapSet.member?(desired_ids, id) do
      Logger.info("stopping upstream #{id}: config disabled or removed")
      Upstream.stop(id)
    end

    %{state | managed: desired_ids}
  end

  @spec start_upstream(Config.t()) :: :ok
  defp start_upstream(config) do
    with {:ok, env} <- Config.resolve_env(config.env),
         {:ok, _pid} <- Upstream.start(config.id, start_opts(config, env)) do
      Logger.info("started upstream #{config.id} (#{config.command})")
    else
      {:error, reason} ->
        Logger.warning("upstream #{config.id} failed to start: #{inspect(reason)}")
    end

    :ok
  end

  @spec start_opts(Config.t(), %{String.t() => String.t()}) :: keyword()
  defp start_opts(config, env) do
    [command: config.command, args: config.args, env: env] ++
      if config.cwd, do: [cwd: config.cwd], else: []
  end
end
