defmodule Root.MCP.Server.Proxy.Token do
  @moduledoc """
  Stateless bearer tokens for the proxy endpoint.

  Signed with the Phoenix endpoint's secret key base. Minted per composition
  execution (the embedded metadata identifies the execution for attribution),
  or manually via `mint/1` in iex for debugging. Verified by
  `RootWeb.Plugs.ProxyAuth`.

  For manual testing, a static token can be configured (dev-only by default,
  see `config/dev.exs`):

      config :root_mcp, :proxy_static_token, "..."
  """

  @salt "mcp-proxy-token"
  @max_age_seconds 3600

  @spec mint(term()) :: String.t()
  def mint(meta \\ %{}) do
    Phoenix.Token.sign(RootWeb.Endpoint, @salt, meta)
  end

  @spec verify(String.t()) :: {:ok, term()} | {:error, :expired | :invalid | :missing}
  def verify(token) do
    static_token = Application.get_env(:root_mcp, :proxy_static_token)

    if static_token && Plug.Crypto.secure_compare(token, static_token) do
      {:ok, %{"exec" => "static-token"}}
    else
      Phoenix.Token.verify(RootWeb.Endpoint, @salt, token, max_age: @max_age_seconds)
    end
  end
end
