defmodule Nopass.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema

      @timestamps_opts [
        type: :integer,
        autogenerate: {System, :os_time, [:second]}
      ]
    end
  end
end

defmodule Nopass.Schema.OneTimePassword do
  use Nopass.Schema
  import Ecto.Changeset

  schema "one_time_passwords" do
    field(:identity, :string)
    field(:password, :string)
    field(:expires_at, :integer)
    timestamps()
  end
end

defmodule Nopass.Schema.LoginToken do
  use Nopass.Schema
  import Ecto.Changeset

  schema "login_tokens" do
    field(:identity, :string)
    field(:login_token, :string)
    field(:expires_at, :integer)
    timestamps()
  end
end
