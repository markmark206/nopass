defmodule Nopass.Schema.Base do
  @moduledoc false

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
  @moduledoc false

  use Nopass.Schema.Base

  schema "one_time_passwords" do
    field(:identity, :string)
    field(:password, :string)
    field(:expires_at, :integer)
    timestamps()
  end
end

defmodule Nopass.Schema.LoginToken do
  @moduledoc false
  use Nopass.Schema.Base

  schema "login_tokens" do
    field(:identity, :string)
    field(:login_token, :string)
    field(:expires_at, :integer)
    timestamps()
  end
end
