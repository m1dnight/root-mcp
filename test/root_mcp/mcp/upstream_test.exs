defmodule Root.MCP.UpstreamTest do
  use ExUnit.Case, async: false

  alias Root.MCP.Upstream

  @fixture Path.expand("../../support/fixtures/stdio_echo_server.exs", __DIR__)

  defp start_upstream(id) do
    {:ok, pid} = Upstream.start(id, command: "elixir", args: [@fixture])
    on_exit(fn -> Upstream.stop(id) end)
    :ok = Upstream.await_ready(id, timeout: 15_000)
    pid
  end

  test "spawns a subprocess and talks MCP to it over stdio" do
    start_upstream("echo-main")

    assert :pong = Upstream.ping("echo-main")
    assert %{"name" => "stdio-echo"} = Upstream.server_info("echo-main")

    assert {:ok, %{result: %{"tools" => [%{"name" => "echo"}]}}} =
             Upstream.list_tools("echo-main")

    assert {:ok, %{result: %{"content" => [%{"type" => "text", "text" => "hello"}]}}} =
             Upstream.call_tool("echo-main", "echo", %{"text" => "hello"})
  end

  test "tracks running upstreams and stops them" do
    start_upstream("echo-a")
    start_upstream("echo-b")

    assert Upstream.list() == ["echo-a", "echo-b"]
    assert is_pid(Upstream.whereis("echo-a"))

    assert :ok = Upstream.stop("echo-a")
    assert Upstream.list() == ["echo-b"]
    assert {:error, :not_found} = Upstream.ping("echo-a")
  end

  test "rejects duplicate ids" do
    pid = start_upstream("echo-dup")

    assert {:error, {:already_started, ^pid}} =
             Upstream.start("echo-dup", command: "elixir", args: [@fixture])
  end

  test "unknown ids and invalid configs are rejected" do
    assert {:error, :not_found} = Upstream.ping("ghost")
    assert {:error, :not_found} = Upstream.stop("ghost")
    assert Upstream.whereis("ghost") == nil
    assert {:error, :missing_command} = Upstream.start("ghost", args: ["x"])
  end
end
