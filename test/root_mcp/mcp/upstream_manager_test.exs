defmodule Root.MCP.UpstreamManagerTest do
  use Root.DataCase, async: false

  @moduletag :capture_log

  alias Root.MCP.Upstream
  alias Root.MCP.Upstream.Config
  alias Root.MCP.Upstream.Config.Store
  alias Root.MCP.Upstream.Manager

  @fixture Path.expand("../../support/fixtures/stdio_echo_server.exs", __DIR__)

  setup do
    manager = start_supervised!({Manager, name: :manager_under_test, enabled: true})
    on_exit(fn -> Upstream.stop("managed-echo") end)
    %{manager: manager}
  end

  defp put_config(fields, %{manager: manager}) do
    {:ok, config} = Config.new(fields)
    :ok = Store.put(config)
    # the broadcast reaches the manager before this call is processed
    _ = :sys.get_state(manager)
    config
  end

  test "starts enabled configs and stops disabled or deleted ones", ctx do
    config =
      put_config(%{id: "managed-echo", command: "elixir", args: [@fixture]}, ctx)

    assert "managed-echo" in Upstream.list()
    assert :ok = Upstream.await_ready("managed-echo", timeout: 15_000)

    put_config(%{config | enabled: false} |> Map.from_struct(), ctx)
    refute "managed-echo" in Upstream.list()

    put_config(Map.from_struct(config), ctx)
    assert "managed-echo" in Upstream.list()

    :ok = Store.delete("managed-echo")
    _ = :sys.get_state(ctx.manager)
    refute "managed-echo" in Upstream.list()
  end

  test "leaves ad-hoc upstreams alone", ctx do
    {:ok, _pid} = Upstream.start("adhoc-echo", command: "elixir", args: [@fixture])
    on_exit(fn -> Upstream.stop("adhoc-echo") end)

    put_config(%{id: "managed-echo", command: "elixir", args: [@fixture]}, ctx)
    :ok = Store.delete("managed-echo")
    _ = :sys.get_state(ctx.manager)

    assert "adhoc-echo" in Upstream.list()
  end

  test "a config whose command cannot start is logged, not fatal", ctx do
    put_config(%{id: "broken", command: "definitely-not-a-command-xyz"}, ctx)

    # the manager survives and other syncs still work
    put_config(%{id: "managed-echo", command: "elixir", args: [@fixture]}, ctx)
    assert "managed-echo" in Upstream.list()
  end
end
