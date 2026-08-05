defmodule Root.Composition do
  @moduledoc """
  A stored composition: a Python script that chains upstream tools, exposed
  as a single reusable MCP tool.

  See `priv/python/harness.py` for the execution contract and
  `Root.Composition.Runner` for how scripts run.
  """

  @enforce_keys [:name, :description, :input_schema, :code]
  defstruct [:name, :description, :input_schema, :code]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          input_schema: map(),
          code: String.t()
        }

  @name_format ~r/^[a-z][a-z0-9_]*$/

  @doc """
  Builds and validates a composition from a map with `:name`, `:description`,
  `:code`, and optional `:input_schema` (defaults to an empty object schema).
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(%{} = fields) do
    composition = %__MODULE__{
      name: fields[:name],
      description: fields[:description],
      input_schema: fields[:input_schema] || %{"type" => "object"},
      code: fields[:code]
    }

    case validate(composition) do
      [] -> {:ok, composition}
      errors -> {:error, Enum.join(errors, "; ")}
    end
  end

  @spec validate(t()) :: [String.t()]
  defp validate(composition) do
    []
    |> validate_name(composition.name)
    |> validate_description(composition.description)
    |> validate_code(composition.code)
  end

  @spec validate_name([String.t()], term()) :: [String.t()]
  defp validate_name(errors, name) when is_binary(name) do
    if name =~ @name_format do
      errors
    else
      errors ++ ["name must be lowercase snake_case (#{inspect(@name_format.source)})"]
    end
  end

  defp validate_name(errors, _name), do: errors ++ ["name is required"]

  @spec validate_description([String.t()], term()) :: [String.t()]
  defp validate_description(errors, description) when is_binary(description) do
    if String.trim(description) == "" do
      errors ++ ["description must not be empty"]
    else
      errors
    end
  end

  defp validate_description(errors, _description), do: errors ++ ["description is required"]

  @spec validate_code([String.t()], term()) :: [String.t()]
  defp validate_code(errors, code) when is_binary(code) do
    if String.contains?(code, "def run") do
      errors
    else
      errors ++ ["code must define the entry point `def run(args)` (see composition_guide)"]
    end
  end

  defp validate_code(errors, _code), do: errors ++ ["code is required"]
end
