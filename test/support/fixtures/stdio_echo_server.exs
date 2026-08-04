# Minimal stdio MCP server used to exercise Root.MCP.Upstream in tests.
# Speaks newline-delimited JSON-RPC on stdin/stdout, exposes one `echo` tool.
# Run with: elixir stdio_echo_server.exs
defmodule StdioEchoServer do
  def loop do
    case IO.read(:stdio, :line) do
      :eof ->
        :ok

      {:error, _reason} ->
        :ok

      line ->
        handle(String.trim(line))
        loop()
    end
  end

  defp handle(""), do: :ok

  defp handle(line) do
    message = JSON.decode!(line)
    dispatch(message["method"], message)
  end

  defp dispatch("initialize", %{"id" => id, "params" => params}) do
    respond(id, %{
      "protocolVersion" => params["protocolVersion"],
      "capabilities" => %{"tools" => %{}},
      "serverInfo" => %{"name" => "stdio-echo", "version" => "0.0.1"}
    })
  end

  defp dispatch("ping", %{"id" => id}), do: respond(id, %{})

  defp dispatch("tools/list", %{"id" => id}) do
    respond(id, %{
      "tools" => [
        %{
          "name" => "echo",
          "description" => "Echoes the given text",
          "inputSchema" => %{
            "type" => "object",
            "properties" => %{"text" => %{"type" => "string"}},
            "required" => ["text"]
          }
        }
      ]
    })
  end

  defp dispatch("tools/call", %{"id" => id, "params" => %{"arguments" => %{"text" => text}}}) do
    respond(id, %{"content" => [%{"type" => "text", "text" => text}], "isError" => false})
  end

  # notifications carry no id and expect no response
  defp dispatch(_method, %{"id" => id}) do
    IO.puts(
      JSON.encode!(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "error" => %{"code" => -32601, "message" => "method not found"}
      })
    )
  end

  defp dispatch(_method, _notification), do: :ok

  defp respond(id, result) do
    IO.puts(JSON.encode!(%{"jsonrpc" => "2.0", "id" => id, "result" => result}))
  end
end

StdioEchoServer.loop()
