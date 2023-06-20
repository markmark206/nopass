defmodule Nopass.Repo do
  use Ecto.Repo,
    otp_app: :nopass,
    adapter: Ecto.Adapters.Postgres
end
