defmodule Root.EctoJSON do
  @moduledoc """
  Ecto type storing any JSON-encodable term in a text column.

  Used where a column holds heterogeneous JSON (e.g. upstream args: a list
  mixing literal strings and reference maps), which Ecto's built-in map and
  array types cannot express.
  """

  use Ecto.Type

  @impl true
  def type, do: :string

  @impl true
  def cast(term), do: {:ok, term}

  @impl true
  def dump(term), do: {:ok, JSON.encode!(term)}

  @impl true
  def load(binary) when is_binary(binary), do: {:ok, JSON.decode!(binary)}
end
