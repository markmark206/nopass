import Config

config :nopass, Nopass.Repo,
  database: "nopass_repo",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :nopass, ecto_repos: [Nopass.Repo]

config :logger,
  level: :info,
  format: "$time $metadata[$level] $message\n"
