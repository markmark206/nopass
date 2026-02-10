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
  @moduledoc """
  Schema for login tokens stored in the `login_tokens` table.

  ## Fields

  - `identity` - the user's identity string (e.g. email address)
  - `login_token` - SHA-256 hash of the token (users hold the plaintext version)
  - `expires_at` - expiration time as Unix epoch seconds
  - `last_verified_at` - last verification time as Unix epoch seconds
  - `metadata` - arbitrary map of metadata set via `Nopass.record_access_and_set_metadata/2`
  - `inserted_at` / `updated_at` - auto-managed integer timestamps (Unix epoch seconds)
  """
  use Nopass.Schema.Base

  schema "login_tokens" do
    field(:identity, :string)
    field(:login_token, :string)
    field(:expires_at, :integer)
    field(:last_verified_at, :integer)
    field(:metadata, :map)
    timestamps()
  end
end
