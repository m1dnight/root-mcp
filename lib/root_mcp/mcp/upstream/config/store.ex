defmodule Root.MCP.Upstream.Config.Store do
  @moduledoc """
  Persistent store of upstream configs, keyed by id and backed by
  `Root.Repo`.

  Every mutation broadcasts `:upstream_configs_changed` on `Root.PubSub`
  (see `topic/0`); `Root.MCP.Upstream.Manager` reacts by syncing the
  running upstreams to the enabled configs.
  """

  import Ecto.Query, only: [from: 2]

  alias Root.MCP.Upstream.Config
  alias Root.MCP.Upstream.Config.Record
  alias Root.Repo

  @doc """
  The PubSub topic (on `Root.PubSub`) receiving `:upstream_configs_changed`
  after every mutation.
  """
  @spec topic() :: String.t()
  def topic, do: "upstream_configs"

  @doc "Stores a config under its id, replacing any existing one."
  @spec put(Config.t()) :: :ok
  def put(%Config{} = config) do
    %Record{
      id: config.id,
      command: config.command,
      args: config.args,
      env: config.env,
      cwd: config.cwd,
      enabled: config.enabled
    }
    |> Repo.insert!(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :id
    )

    broadcast_change()
  end

  @doc "Fetches a config by id."
  @spec get(String.t()) :: Config.t() | nil
  def get(id) when is_binary(id) do
    case Repo.get(Record, id) do
      nil -> nil
      record -> to_config(record)
    end
  end

  @doc "Lists all configs, sorted by id."
  @spec list() :: [Config.t()]
  def list do
    from(record in Record, order_by: record.id)
    |> Repo.all()
    |> Enum.map(&to_config/1)
  end

  @doc "Lists the enabled configs, sorted by id."
  @spec list_enabled() :: [Config.t()]
  def list_enabled do
    from(record in Record, where: record.enabled, order_by: record.id)
    |> Repo.all()
    |> Enum.map(&to_config/1)
  end

  @doc "Deletes a config by id."
  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(id) when is_binary(id) do
    case Repo.get(Record, id) do
      nil ->
        {:error, :not_found}

      record ->
        Repo.delete!(record)
        broadcast_change()
    end
  end

  @spec to_config(Record.t()) :: Config.t()
  defp to_config(%Record{} = record) do
    %Config{
      id: record.id,
      command: record.command,
      args: record.args,
      env: record.env,
      cwd: record.cwd,
      enabled: record.enabled
    }
  end

  @spec broadcast_change() :: :ok
  defp broadcast_change do
    Phoenix.PubSub.broadcast(Root.PubSub, topic(), :upstream_configs_changed)
  end
end
