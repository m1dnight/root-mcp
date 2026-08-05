defmodule Root.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RootWeb.Telemetry,
      Root.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:root_mcp, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:root_mcp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Root.PubSub},
      Root.Composition.Store,
      {Registry, keys: :unique, name: Root.MCP.Upstream.Registry},
      {DynamicSupervisor, name: Root.MCP.Upstream.Supervisor, strategy: :one_for_one},
      {Root.MCP.Server.Client,
       transport: {:streamable_http, start: Application.get_env(:root_mcp, :start_mcp_transport)}},
      {Root.MCP.Server.Editor,
       transport: {:streamable_http, start: Application.get_env(:root_mcp, :start_mcp_transport)}},
      {Root.MCP.Server.Proxy,
       transport: {:streamable_http, start: Application.get_env(:root_mcp, :start_mcp_transport)}},
      # Start a worker by calling: Root.Worker.start_link(arg)
      # {Root.Worker, arg},
      # Start to serve requests, typically the last entry
      RootWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Root.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RootWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
