import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :root_mcp, Root.Repo,
  database: Path.expand("../root_mcp_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :root_mcp, RootWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "zxK3N/wpmBhxEy5N5Kf5n8T7Hj2/Sb0hwPiQTCUgYtezLdUbsecN6+LsLCt6p0il",
  server: false

# Tests dispatch through the endpoint without a running HTTP server, so the
# MCP transport must be started explicitly (it normally only starts when
# Phoenix serves endpoints, e.g. under `mix phx.server`)
config :root_mcp, :start_mcp_transport, true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
