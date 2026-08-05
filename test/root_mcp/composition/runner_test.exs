defmodule Root.Composition.RunnerTest do
  use ExUnit.Case, async: false

  alias Root.Composition.Runner
  alias Root.MCP.Upstream

  @fixture Path.expand("../../support/fixtures/stdio_echo_server.exs", __DIR__)

  @chained_script """
  from root import call_tool, text

  def run(args):
      first = text(call_tool("comp", "echo", {"text": args["greeting"]}))
      second = text(call_tool("comp", "echo", {"text": first + " world"}))
      print("this goes to stderr, not the result channel")
      return {"echoed": second, "length": len(second)}
  """

  setup do
    {:ok, _pid} = Upstream.start("comp", command: "elixir", args: [@fixture])
    on_exit(fn -> Upstream.stop("comp") end)
    :ok = Upstream.await_ready("comp", timeout: 15_000)
    :ok
  end

  test "runs a composition that chains upstream tools through the proxy" do
    assert {:ok, %{"echoed" => "hello world", "length" => 11}} =
             Runner.run(@chained_script, %{"greeting" => "hello"})
  end

  test "returns the traceback when the script raises" do
    script = """
    def run(args):
        raise ValueError("boom")
    """

    assert {:error, {:script_error, traceback}} = Runner.run(script, %{})
    assert traceback =~ "ValueError: boom"
  end

  test "kills the script when the deadline elapses" do
    script = """
    import time

    def run(args):
        time.sleep(60)
    """

    assert {:error, :timeout} = Runner.run(script, %{}, timeout: 1000)
  end

  test "reports malformed scripts as script errors" do
    assert {:error, {:script_error, traceback}} = Runner.run("def run(", %{})
    assert traceback =~ "SyntaxError"
  end
end
