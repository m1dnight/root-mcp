defmodule Root.MCP.Server.Editor.Tools.TestComposition do
  @moduledoc "Runs a composition against the live upstreams and returns its result, or the Python traceback on failure. Pass `name` to run a stored composition, or `code` to iterate on a script before storing it"

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias Root.Composition
  alias Root.Composition.Runner
  alias Root.Composition.Store

  schema do
    field :name, :string, description: "name of a stored composition to run"

    field :code, :string,
      description: "inline script to run instead of a stored composition (must define run(args))"

    field :args, :map, description: "arguments passed to run(args) (default: {})"
  end

  @impl true
  def execute(params, frame) do
    args = Map.get(params, :args) || %{}

    case resolve_code(Map.get(params, :name), Map.get(params, :code)) do
      {:ok, code} -> {:reply, run(code, args), frame}
      {:error, message} -> {:reply, Response.error(Response.tool(), message), frame}
    end
  end

  @spec resolve_code(String.t() | nil, String.t() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  defp resolve_code(nil, nil), do: {:error, "pass either name or code"}
  defp resolve_code(nil, code), do: {:ok, code}

  defp resolve_code(name, nil) do
    case Store.get(name) do
      %Composition{code: code} -> {:ok, code}
      nil -> {:error, "no such composition: #{name}"}
    end
  end

  defp resolve_code(_name, _code), do: {:error, "pass either name or code, not both"}

  @spec run(String.t(), map()) :: Response.t()
  defp run(code, args) do
    case Runner.run(code, args) do
      {:ok, result} -> Response.json(Response.tool(), %{result: result})
      {:error, reason} -> Response.error(Response.tool(), describe(reason))
    end
  end

  @spec describe(Runner.run_error()) :: String.t()
  defp describe({:script_error, traceback}), do: "script failed:\n" <> traceback

  defp describe({:abnormal_exit, status, output}),
    do: "python exited with status #{status}:\n" <> output

  defp describe(:timeout), do: "timed out (default deadline is 30s)"
  defp describe(:python_not_found), do: "python3 not found on PATH"
end
