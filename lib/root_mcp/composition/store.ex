defmodule Root.Composition.Store do
  @moduledoc """
  Persistent store of compositions, keyed by name and backed by `Root.Repo`
  (SQLite), so authored compositions survive restarts.

  Every mutation broadcasts `:compositions_changed` on `Root.PubSub` (see
  `topic/0`); `Root.MCP.Server.Client.Notifier` relays that to connected
  client-mode sessions.
  """

  import Ecto.Query, only: [from: 2]

  alias Root.Composition
  alias Root.Composition.Record
  alias Root.Repo

  @doc """
  The PubSub topic (on `Root.PubSub`) receiving `:compositions_changed`
  after every mutation.
  """
  @spec topic() :: String.t()
  def topic, do: "compositions"

  @doc """
  Stores a composition under its name, replacing any existing one.

  ## Example

      {:ok, composition} =
        Root.Composition.new(%{
          name: "greet",
          description: "Greets someone by name",
          code: "def run(args):\\n    return {\\"greeting\\": \\"hi \\" + args[\\"who\\"]}"
        })

      Root.Composition.Store.put(composition)
      # => :ok
  """
  @spec put(Composition.t()) :: :ok
  def put(%Composition{} = composition) do
    %Record{
      name: composition.name,
      description: composition.description,
      input_schema: composition.input_schema,
      code: composition.code
    }
    |> Repo.insert!(
      on_conflict: {:replace_all_except, [:name, :inserted_at]},
      conflict_target: :name
    )

    broadcast_change()
  end

  @doc """
  Fetches a composition by name.

  ## Example

      Root.Composition.Store.get("greet")
      # => %Root.Composition{name: "greet", ...}

      Root.Composition.Store.get("unknown")
      # => nil
  """
  @spec get(String.t()) :: Composition.t() | nil
  def get(name) when is_binary(name) do
    case Repo.get(Record, name) do
      nil -> nil
      record -> to_composition(record)
    end
  end

  @doc """
  Lists all compositions, sorted by name.

  ## Example

      Root.Composition.Store.list()
      # => [%Root.Composition{name: "copy_files", ...}, %Root.Composition{name: "greet", ...}]
  """
  @spec list() :: [Composition.t()]
  def list do
    from(record in Record, order_by: record.name)
    |> Repo.all()
    |> Enum.map(&to_composition/1)
  end

  @doc """
  Deletes a composition by name.

  ## Example

      Root.Composition.Store.delete("greet")
      # => :ok

      Root.Composition.Store.delete("greet")
      # => {:error, :not_found}
  """
  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(name) when is_binary(name) do
    case Repo.get(Record, name) do
      nil ->
        {:error, :not_found}

      record ->
        Repo.delete!(record)
        broadcast_change()
    end
  end

  @spec to_composition(Record.t()) :: Composition.t()
  defp to_composition(%Record{} = record) do
    %Composition{
      name: record.name,
      description: record.description,
      input_schema: record.input_schema,
      code: record.code
    }
  end

  @spec broadcast_change() :: :ok
  defp broadcast_change do
    Phoenix.PubSub.broadcast(Root.PubSub, topic(), :compositions_changed)
  end
end
