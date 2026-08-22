defmodule Nopass.Repo do
  # Ecto needs the adapter at compile time, so this cannot be runtime config. The Postgres
  # default is the compatibility contract for consumers who configure nothing.
  use Ecto.Repo,
    otp_app: :nopass,
    adapter: Application.compile_env(:nopass, :adapter, Ecto.Adapters.Postgres)
end
