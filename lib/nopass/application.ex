defmodule Nopass.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Nopass.Repo,
      {Ecto.Migrator, repos: [Nopass.Repo]}
      # Starts a worker by calling: Nopass.Worker.start_link(arg)
      # {Nopass.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nopass.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
