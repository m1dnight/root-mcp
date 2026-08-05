defmodule RootWeb.Router do
  use RootWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RootWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :proxy_auth do
    plug RootWeb.Plugs.ProxyAuth
  end

  scope "/", RootWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/compositions", CompositionLive
    live "/compositions/:name", CompositionLive
    live "/vault", VaultLive
    live "/upstreams", UpstreamLive
  end

  # The MCP scopes must NOT pipe through :api — its `accepts ["json"]` plug
  # 406s the SSE GET stream (Accept: text/event-stream) that clients open for
  # server-initiated notifications. The Anubis plug validates Accept itself.

  # must precede the "/mcp" scope: its catch-all forward would swallow "/mcp/proxy"
  scope "/mcp/proxy" do
    pipe_through :proxy_auth

    forward "/", Anubis.Server.Transport.StreamableHTTP.Plug, server: Root.MCP.Server.Proxy
  end

  scope "/mcp" do
    # more specific forward first: "/" would swallow "/editor"
    forward "/editor", Anubis.Server.Transport.StreamableHTTP.Plug, server: Root.MCP.Server.Editor
    forward "/", Anubis.Server.Transport.StreamableHTTP.Plug, server: Root.MCP.Server.Client
  end

  # Other scopes may use custom stacks.
  # scope "/api", RootWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:root_mcp, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RootWeb.Telemetry
    end
  end
end
