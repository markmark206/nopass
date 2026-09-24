import Config

adapter =
  case System.get_env("NOPASS_ADAPTER", "postgres") do
    "postgres" -> Ecto.Adapters.Postgres
    "sqlite" -> Ecto.Adapters.SQLite3
    other -> raise "unknown NOPASS_ADAPTER #{inspect(other)}; expected \"postgres\" or \"sqlite\""
  end

config :nopass, ecto_repos: [Nopass.Repo]

case adapter do
  Ecto.Adapters.Postgres ->
    # :adapter is left unset so these runs exercise Nopass.Repo's compile_env default, which is what
    # a consumer who configures no adapter gets.
    config :nopass, Nopass.Repo,
      pool: Ecto.Adapters.SQL.Sandbox,
      database: "nopass_repo",
      username: "postgres",
      password: "postgres",
      hostname: "localhost"

  Ecto.Adapters.SQLite3 ->
    config :nopass, adapter: Ecto.Adapters.SQLite3

    config :nopass, Nopass.Repo,
      pool: Ecto.Adapters.SQL.Sandbox,
      database: "nopass_repo.db",
      busy_timeout: 5_000,
      default_transaction_mode: :immediate
end

config :logger,
  level: :info,
  format: "$time $metadata[$level] $message\n"
