defmodule Root.MCP.Upstream.Config do
  @moduledoc """
  A persisted upstream definition: how to spawn an upstream MCP server.

  Enabled configs are started automatically by `Root.MCP.Upstream.Manager`.

  The `env` map's values and the `args` entries are either literal strings
  or references resolved at spawn time — the stored config (and anything
  reading it) never holds secret values:

    * `"literal"` — passed through as-is
    * `%{"$env" => "NAME"}` — read from Root's own environment
    * `%{"$secret" => "name"}` — read from `Root.Vault`

  Prefer env for credentials: command-line arguments are visible in the
  machine's process list, environment variables are not.
  """

  @enforce_keys [:id, :command]
  defstruct [:id, :command, :cwd, args: [], env: %{}, enabled: true]

  @type template_value :: String.t() | %{String.t() => String.t()}
  @type t :: %__MODULE__{
          id: String.t(),
          command: String.t(),
          args: [template_value()],
          env: %{String.t() => template_value()},
          cwd: String.t() | nil,
          enabled: boolean()
        }

  @id_format ~r/^[a-z0-9][a-z0-9-]*$/

  @doc """
  Builds and validates a config from a map with `:id` and `:command`,
  and optional `:args`, `:env`, `:cwd`, `:enabled`.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(%{} = fields) do
    config = %__MODULE__{
      id: fields[:id],
      command: fields[:command],
      args: fields[:args] || [],
      env: fields[:env] || %{},
      cwd: fields[:cwd],
      enabled: Map.get(fields, :enabled, true)
    }

    case validate(config) do
      [] -> {:ok, config}
      errors -> {:error, Enum.join(errors, "; ")}
    end
  end

  @doc """
  Resolves the env map's references into literal values, ready for
  injection into the subprocess environment.
  """
  @spec resolve_env(%{String.t() => template_value()}) ::
          {:ok, %{String.t() => String.t()}}
          | {:error, {:missing_env, String.t()} | {:missing_secret, String.t()}}
  def resolve_env(%{} = env) do
    Enum.reduce_while(env, {:ok, %{}}, fn {key, value}, {:ok, resolved} ->
      case resolve_value(value) do
        {:ok, literal} -> {:cont, {:ok, Map.put(resolved, key, literal)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Resolves the args list's references into literal strings, ready to be
  passed to the subprocess.
  """
  @spec resolve_args([template_value()]) ::
          {:ok, [String.t()]}
          | {:error, {:missing_env, String.t()} | {:missing_secret, String.t()}}
  def resolve_args(args) when is_list(args) do
    args
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, resolved} ->
      case resolve_value(value) do
        {:ok, literal} -> {:cont, {:ok, [literal | resolved]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, resolved} -> {:ok, Enum.reverse(resolved)}
      error -> error
    end
  end

  @spec resolve_value(template_value()) ::
          {:ok, String.t()} | {:error, {:missing_env | :missing_secret, String.t()}}
  defp resolve_value(literal) when is_binary(literal), do: {:ok, literal}

  defp resolve_value(%{"$env" => name}) do
    case System.get_env(name) do
      nil -> {:error, {:missing_env, name}}
      value -> {:ok, value}
    end
  end

  defp resolve_value(%{"$secret" => name}) do
    case Root.Vault.fetch(name) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_secret, name}}
    end
  end

  @spec validate(t()) :: [String.t()]
  defp validate(config) do
    []
    |> validate_id(config.id)
    |> validate_command(config.command)
    |> validate_args(config.args)
    |> validate_env(config.env)
  end

  @spec validate_id([String.t()], term()) :: [String.t()]
  defp validate_id(errors, id) when is_binary(id) do
    if id =~ @id_format do
      errors
    else
      # no underscores: proxied tools are advertised as <id>__<tool>
      errors ++ ["id must be lowercase letters, digits, and hyphens"]
    end
  end

  defp validate_id(errors, _id), do: errors ++ ["id is required"]

  @spec validate_command([String.t()], term()) :: [String.t()]
  defp validate_command(errors, command) when is_binary(command) and command != "", do: errors
  defp validate_command(errors, _command), do: errors ++ ["command is required"]

  @spec validate_args([String.t()], term()) :: [String.t()]
  defp validate_args(errors, args) do
    if is_list(args) and Enum.all?(args, &valid_template_value?/1) do
      errors
    else
      errors ++
        [~s(args must be strings, {"$env": "NAME"}, or {"$secret": "name"} references)]
    end
  end

  @spec validate_env([String.t()], term()) :: [String.t()]
  defp validate_env(errors, %{} = env) do
    if Enum.all?(env, fn {key, value} -> is_binary(key) and valid_template_value?(value) end) do
      errors
    else
      errors ++
        [~s(env values must be strings, {"$env": "NAME"}, or {"$secret": "name"} references)]
    end
  end

  defp validate_env(errors, _env), do: errors ++ ["env must be a map"]

  @spec valid_template_value?(term()) :: boolean()
  defp valid_template_value?(value) when is_binary(value), do: true
  defp valid_template_value?(%{"$env" => name}) when is_binary(name), do: true
  defp valid_template_value?(%{"$secret" => name}) when is_binary(name), do: true
  defp valid_template_value?(_other), do: false
end
