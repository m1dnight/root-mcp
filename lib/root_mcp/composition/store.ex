defmodule Root.Composition.Store do
  @moduledoc """
  In-memory store of compositions, keyed by name.

  Contents are lost on restart; persistence is a planned follow-up.
  """

  use GenServer

  alias Root.Composition

  @doc """
  Starts the store.

  ## Example

      # in a supervision tree (uses the module name)
      children = [Root.Composition.Store]

      # a private instance, e.g. in tests
      start_supervised!({Root.Composition.Store, name: :my_store})
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, name: Keyword.get(opts, :name, __MODULE__))
  end

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
  @spec put(GenServer.server(), Composition.t()) :: :ok
  def put(store \\ __MODULE__, %Composition{} = composition) do
    GenServer.call(store, {:put, composition})
  end

  @doc """
  Fetches a composition by name.

  ## Example

      Root.Composition.Store.get("greet")
      # => %Root.Composition{name: "greet", ...}

      Root.Composition.Store.get("unknown")
      # => nil
  """
  @spec get(GenServer.server(), String.t()) :: Composition.t() | nil
  def get(store \\ __MODULE__, name) when is_binary(name) do
    GenServer.call(store, {:get, name})
  end

  @doc """
  Lists all compositions, sorted by name.

  ## Example

      Root.Composition.Store.list()
      # => [%Root.Composition{name: "copy_files", ...}, %Root.Composition{name: "greet", ...}]
  """
  @spec list(GenServer.server()) :: [Composition.t()]
  def list(store \\ __MODULE__) do
    GenServer.call(store, :list)
  end

  @doc """
  Deletes a composition by name.

  ## Example

      Root.Composition.Store.delete("greet")
      # => :ok

      Root.Composition.Store.delete("greet")
      # => {:error, :not_found}
  """
  @spec delete(GenServer.server(), String.t()) :: :ok | {:error, :not_found}
  def delete(store \\ __MODULE__, name) when is_binary(name) do
    GenServer.call(store, {:delete, name})
  end

  @impl true
  def init(compositions), do: {:ok, compositions}

  @impl true
  def handle_call({:put, composition}, _from, compositions) do
    {:reply, :ok, Map.put(compositions, composition.name, composition)}
  end

  def handle_call({:get, name}, _from, compositions) do
    {:reply, Map.get(compositions, name), compositions}
  end

  def handle_call(:list, _from, compositions) do
    {:reply, compositions |> Map.values() |> Enum.sort_by(& &1.name), compositions}
  end

  def handle_call({:delete, name}, _from, compositions) do
    case Map.pop(compositions, name) do
      {nil, _} -> {:reply, {:error, :not_found}, compositions}
      {_composition, rest} -> {:reply, :ok, rest}
    end
  end
end
