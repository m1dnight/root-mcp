defmodule Root.Composition.Runner do
  @moduledoc """
  Executes a composition script in a `python3` subprocess.

  The script must define `run(args)` and may call upstream tools through the
  `root` helper (see `priv/python/root.py`), which talks to the `/mcp/proxy`
  endpoint using a per-execution bearer token injected via the environment.

  The subprocess is fed the arguments as one JSON line on stdin and must
  print a single JSON envelope on stdout (handled by `priv/python/harness.py`);
  it is killed when the timeout elapses.
  """

  alias Root.MCP.Server.Proxy.Token

  @default_timeout to_timeout(second: 30)

  @type run_error ::
          {:script_error, traceback :: String.t()}
          | {:abnormal_exit, status :: non_neg_integer(), output :: String.t()}
          | :timeout
          | :python_not_found

  @doc """
  Runs the composition `code` with the given `args`.

  ## Options

    * `:timeout` - overall deadline in milliseconds (default 30s)
    * `:proxy_url` - proxy endpoint URL (defaults to this node's endpoint)
  """
  @spec run(String.t(), map(), keyword()) :: {:ok, term()} | {:error, run_error()}
  def run(code, args, opts \\ []) when is_binary(code) and is_map(args) do
    with {:ok, python} <- find_python() do
      run_dir = create_run_dir!()
      script_path = Path.join(run_dir, "script.py")
      File.write!(script_path, code)

      try do
        python
        |> spawn_script(script_path, opts)
        |> feed_args(args)
        |> await_result(Keyword.get(opts, :timeout, @default_timeout))
      after
        File.rm_rf(run_dir)
      end
    end
  end

  @doc "Human-readable description of a run error, suitable for tool error responses."
  @spec describe_error(run_error()) :: String.t()
  def describe_error({:script_error, traceback}), do: "script failed:\n" <> traceback

  def describe_error({:abnormal_exit, status, output}),
    do: "python exited with status #{status}:\n" <> output

  def describe_error(:timeout), do: "timed out (default deadline is 30s)"
  def describe_error(:python_not_found), do: "python3 not found on PATH"

  @spec find_python() :: {:ok, Path.t()} | {:error, :python_not_found}
  defp find_python do
    case System.find_executable("python3") do
      nil -> {:error, :python_not_found}
      path -> {:ok, path}
    end
  end

  @spec create_run_dir!() :: Path.t()
  defp create_run_dir! do
    unique = Base.url_encode64(:crypto.strong_rand_bytes(9))
    dir = Path.join(System.tmp_dir!(), "rootmcp-composition-#{unique}")
    File.mkdir_p!(dir)
    dir
  end

  @spec spawn_script(Path.t(), Path.t(), keyword()) :: port()
  defp spawn_script(python, script_path, opts) do
    python_dir = Path.join(:code.priv_dir(:root_mcp), "python")
    proxy_url = Keyword.get(opts, :proxy_url, default_proxy_url())
    exec_id = Base.url_encode64(:crypto.strong_rand_bytes(9))

    Port.open({:spawn_executable, python}, [
      :binary,
      :exit_status,
      :hide,
      args: [Path.join(python_dir, "harness.py"), script_path],
      env: [
        {~c"PYTHONPATH", String.to_charlist(python_dir)},
        {~c"ROOT_MCP_URL", String.to_charlist(proxy_url)},
        {~c"ROOT_MCP_TOKEN", String.to_charlist(Token.mint(%{"exec" => exec_id}))}
      ]
    ])
  end

  @spec feed_args(port(), map()) :: port()
  defp feed_args(port, args) do
    Port.command(port, [JSON.encode!(args), ?\n])
    port
  end

  @spec await_result(port(), timeout()) :: {:ok, term()} | {:error, run_error()}
  defp await_result(port, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    collect_output(port, [], deadline)
  end

  @spec collect_output(port(), iodata(), integer()) :: {:ok, term()} | {:error, run_error()}
  defp collect_output(port, acc, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^port, {:data, data}} ->
        collect_output(port, [acc | data], deadline)

      {^port, {:exit_status, status}} ->
        parse_envelope(status, IO.iodata_to_binary(acc))
    after
      remaining ->
        kill(port)
        {:error, :timeout}
    end
  end

  @spec parse_envelope(non_neg_integer(), String.t()) :: {:ok, term()} | {:error, run_error()}
  defp parse_envelope(status, output) do
    case JSON.decode(output |> String.split("\n", trim: true) |> List.last() || "") do
      {:ok, %{"status" => "ok", "result" => result}} ->
        {:ok, result}

      {:ok, %{"status" => "error", "traceback" => traceback}} ->
        {:error, {:script_error, traceback}}

      _malformed ->
        {:error, {:abnormal_exit, status, output}}
    end
  end

  @spec kill(port()) :: :ok
  defp kill(port) do
    with {:os_pid, os_pid} <- Port.info(port, :os_pid) do
      System.cmd("kill", ["-9", Integer.to_string(os_pid)])
    end

    if Port.info(port), do: Port.close(port)
    :ok
  end

  @spec default_proxy_url() :: String.t()
  defp default_proxy_url, do: RootWeb.Endpoint.url() <> "/mcp/proxy"
end
