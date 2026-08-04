defmodule Root.Repo do
  use Ecto.Repo,
    otp_app: :root_mcp,
    adapter: Ecto.Adapters.SQLite3
end
