defmodule Root.Vault do
  @moduledoc """
  Named secrets, encrypted at rest, for injection into upstream MCP
  environments.

  Values are encrypted with the Phoenix endpoint's secret key base
  (authenticated encryption via `Plug.Crypto`) before touching the database.
  Secret values must never be exposed through any MCP surface: they enter
  via the web UI or iex, and leave only by being injected into an upstream
  subprocess's environment at spawn time (see
  `Root.MCP.Upstream.Config.resolve_env/1`). Everything else — listings,
  upstream configs, agent conversations — handles secret *names* only.
  """

  import Ecto.Query, only: [from: 2]

  alias Root.Repo
  alias Root.Vault.Record

  @salt "root vault"

  @doc "Stores a secret under `name`, replacing any existing value."
  @spec put(String.t(), String.t()) :: :ok
  def put(name, value) when is_binary(name) and is_binary(value) do
    %Record{name: name, value: encrypt(value)}
    |> Repo.insert!(
      on_conflict: {:replace_all_except, [:name, :inserted_at]},
      conflict_target: :name
    )

    :ok
  end

  @doc "Fetches and decrypts a secret."
  @spec fetch(String.t()) :: {:ok, String.t()} | :error
  def fetch(name) when is_binary(name) do
    with %Record{value: token} <- Repo.get(Record, name),
         {:ok, value} <- decrypt(token) do
      {:ok, value}
    else
      _missing_or_undecryptable -> :error
    end
  end

  @doc "Lists the stored secret names (never the values), sorted."
  @spec list() :: [String.t()]
  def list do
    Repo.all(from(record in Record, select: record.name, order_by: record.name))
  end

  @doc "Deletes a secret."
  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(name) when is_binary(name) do
    case Repo.get(Record, name) do
      nil ->
        {:error, :not_found}

      record ->
        Repo.delete!(record)
        :ok
    end
  end

  @spec encrypt(String.t()) :: binary()
  defp encrypt(value), do: Plug.Crypto.encrypt(key_base(), @salt, value)

  @spec decrypt(binary()) :: {:ok, String.t()} | {:error, term()}
  defp decrypt(token), do: Plug.Crypto.decrypt(key_base(), @salt, token, max_age: :infinity)

  @spec key_base() :: String.t()
  defp key_base, do: RootWeb.Endpoint.config(:secret_key_base)
end
