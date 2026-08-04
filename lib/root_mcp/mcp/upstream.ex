defmodule Root.MCP.Upstream do
  @moduledoc """
  Upstreams: external MCP servers that RootMCP spawns as OS subprocesses and
  talks to over stdio.

  Each upstream is identified by a caller-chosen string id and runs as a
  supervised pair of processes: an `Anubis.Client` GenServer speaking MCP,
  plus a stdio transport that owns the OS process. The pair lives under
  `Root.MCP.Upstream.Supervisor` and is found through
  `Root.MCP.Upstream.Registry`.

  If the subprocess dies, the pair restarts together (respawning the
  subprocess). If it keeps dying, the upstream is dropped entirely and
  `start/2` may be called again — restarting a command that cannot run
  does not remedy anything.

      {:ok, _pid} = Root.MCP.Upstream.start("time", command: "uvx", args: ["mcp-server-time"])
      :ok = Root.MCP.Upstream.await_ready("time")
      {:ok, response} = Root.MCP.Upstream.call_tool("time", "get_current_time", %{"timezone" => "UTC"})
  """

  alias Anubis.Client

  @registry Root.MCP.Upstream.Registry
  @supervisor Root.MCP.Upstream.Supervisor

  @protocol_version "2025-06-18"
  @transport_keys [:args, :env, :cwd]

  @type id :: String.t()

  @doc """
  Spawns an upstream running `command` as an OS subprocess.

  ## Options

    * `:command` - executable to run, resolved against `$PATH` (required)
    * `:args` - list of argument strings
    * `:env` - map of extra environment variables
    * `:cwd` - working directory for the subprocess
  """
  @spec start(id, keyword()) :: {:ok, pid()} | {:error, term()}
  def start(id, config) when is_binary(id) and is_list(config) do
    with {:ok, transport} <- build_transport(config) do
      client_opts = [
        name: via(id, :client),
        transport_name: via(id, :transport),
        transport: transport,
        # the name must be unique per upstream: Anubis derives its client-side
        # ETS cache table from it, and a shared name makes clients crash on
        # each other's tables when several upstreams process tools/list
        client_info: %{"name" => "RootMCP upstream #{id}", "version" => "0.1.0"},
        protocol_version: @protocol_version
      ]

      # Anubis.Client expects a name to be an atom and it derives the names for
      # the supervisor based on that. We don't have names as atoms at runtime,
      # and we want to use the registry, so we create our own child spec to put
      # in the registry names.
      spec = %{
        id: {:upstream, id},
        start:
          {Supervisor, :start_link,
           [Client.Supervisor, client_opts, [name: via(id, :supervisor)]]},
        type: :supervisor,
        restart: :temporary
      }

      DynamicSupervisor.start_child(@supervisor, spec)
    end
  end

  @doc "Stops an upstream, terminating its OS subprocess."
  @spec stop(id) :: :ok | {:error, :not_found}
  def stop(id) when is_binary(id) do
    case Registry.lookup(@registry, {id, :supervisor}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(@supervisor, pid)
      [] -> {:error, :not_found}
    end
  end

  @doc "Lists the ids of all running upstreams."
  @spec list() :: [id]
  def list do
    @registry
    |> Registry.select([{{{:"$1", :client}, :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.filter(fn {_id, pid} -> Process.alive?(pid) end)
    |> Enum.map(fn {id, _pid} -> id end)
    |> Enum.sort()
  end

  @doc "Returns the client pid for an upstream, or `nil` if not running."
  @spec whereis(id) :: pid() | nil
  def whereis(id) when is_binary(id) do
    case Registry.lookup(@registry, {id, :client}) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc "Blocks until the MCP handshake with the subprocess has completed."
  @spec await_ready(id, keyword()) :: :ok | {:error, :not_found}
  def await_ready(id, opts \\ []), do: with_client(id, &Client.await_ready(&1, opts))

  @doc "Pings the upstream's server."
  @spec ping(id, keyword()) :: :pong | {:error, term()}
  def ping(id, opts \\ []), do: with_client(id, &Client.ping(&1, opts))

  @doc "Returns the server info reported by the upstream during the handshake."
  @spec server_info(id) :: map() | nil | {:error, :not_found}
  def server_info(id), do: with_client(id, &Client.get_server_info/1)

  @doc "Lists the tools exposed by the upstream."
  @spec list_tools(id, keyword()) :: {:ok, Anubis.MCP.Response.t()} | {:error, term()}
  def list_tools(id, opts \\ []), do: with_client(id, &Client.list_tools(&1, opts))

  @doc "Calls a tool on the upstream."
  @spec call_tool(id, String.t(), map() | nil, keyword()) ::
          {:ok, Anubis.MCP.Response.t()} | {:error, term()}
  def call_tool(id, name, arguments \\ nil, opts \\ []) do
    with_client(id, &Client.call_tool(&1, name, arguments, opts))
  end

  # builds the transport config passed to Anubis
  @spec build_transport(keyword()) :: {:ok, {:stdio, keyword()}} | {:error, :missing_command}
  defp build_transport(config) do
    case Keyword.fetch(config, :command) do
      {:ok, command} when is_binary(command) ->
        {:ok, {:stdio, [command: command] ++ Keyword.take(config, @transport_keys)}}

      _missing_or_invalid ->
        {:error, :missing_command}
    end
  end

  @spec with_client(id, (pid() -> result)) :: result | {:error, :not_found} when result: term()
  defp with_client(id, fun) when is_binary(id) do
    case Registry.lookup(@registry, {id, :client}) do
      [{pid, _}] -> fun.(pid)
      [] -> {:error, :not_found}
    end
  catch
    # the upstream died between lookup and call
    :exit, {:noproc, _} -> {:error, :not_found}
  end

  @spec via(id, :supervisor | :client | :transport) :: GenServer.name()
  defp via(id, role), do: {:via, Registry, {@registry, {id, role}}}
end
