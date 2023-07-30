defmodule Nopass do
  @moduledoc """
  This module implements the logic needed for implementing passwordless authentication, which relies on magic codes (aka "one-time passwords") and login tokens.

  This passwordless authentication sequence involves your application sending a one-time password to the user's mailbox.
  The user, then, asks your application to trade the one-time password for a more long-term login token.
  After your application issues the login token to the user, the user uses the login token to prove their identity during future interactions with your applications.

  This module simplifies implementing this sequence, by providing the following functions:
  1. `new_one_time_password()`: generates a new one-time password,
  2. `trade_one_time_password_for_login_token()`: trades a valid one-time password for a login token,
  3. `verify_login_token()`: verifies a login token,
  4. `delete_login_token()`: deletes a login token.

  The module relies on a postgres database, where it maintains two tables, `one_time_passwords` and `login_tokens`, which means that login tokens can be revoked.

  Examples:
      iex> one_time_password = Nopass.new_one_time_password("luigi@mansion")
      iex> {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password)
      iex> Nopass.verify_login_token(login_token)
      {:ok, "luigi@mansion"}
      iex> Nopass.delete_login_token(login_token)
      :ok
      iex> Nopass.verify_login_token(login_token)
      {:error, :expired_or_missing}
  """

  import Ecto.Query
  require Logger

  @password_dictionary Enum.to_list(?a..?z) ++ Enum.to_list(?A..?Z) ++ Enum.to_list(?0..?9)

  @doc ~S"""
  Generates a one-time password for an entity.

  Parameters:
     `entity`: the entity (e.g. email address) for which you are generating the one-time password
     `opts`: optional options, including:
       `expires`_after_seconds: the lifetime of the generated one-time passwords after which the password expires. Optional, default: 600
       `length`: the length of the random portion of the one-time password. Optional, default: 20

  ## Examples

      iex> _one_time_password = Nopass.new_one_time_password("luigi@mansion", after_seconds: 900, length: 30)
  """
  def new_one_time_password(entity, opts \\ []) do
    one_time_password_params =
      Enum.into(opts, %{
        expires_after_seconds: 600,
        length: 20
      })

    one_time_password = "otp" <> Nanoid.generate(one_time_password_params.length, @password_dictionary)
    expires_at = System.os_time(:second) + one_time_password_params.expires_after_seconds

    %Nopass.Schema.OneTimePassword{
      identity: entity,
      password: one_time_password,
      expires_at: expires_at
    }
    |> Nopass.Repo.insert!()

    one_time_password
  end

  @doc ~S"""
  Trades a valid one-time password for login token. A one-time password can only be used once.

  Parameters:
     `one_time_password`: the one-time password to verify and consume.
     `opts`: optional options, including:
       `expires`_after_seconds: the lifetime of the generated login token, in seconds, after which the login token expires. Optional, default: 86400 (one day)
       `length`: the length of the random portion of the login token to be generated. Optional, default: 50
       'login_token_identity': the value of the identity to be associated with the login token or the function for computing it, based on the value of the one-time-password's identity. Optional, default: the identity associated with the one-time password.

  ## Examples

      iex> one_time_password = Nopass.new_one_time_password("luigi@mansion")
      iex> {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password, login_token_identity: fn x -> "user known as " <> x end)
      iex> Nopass.verify_login_token(login_token)
      {:ok, "user known as luigi@mansion"}
      iex> {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token(one_time_password)
  """
  def trade_one_time_password_for_login_token(one_time_password, opts \\ []) do
    login_token_params =
      Enum.into(opts, %{
        login_token_identity: fn otp_identity -> otp_identity end,
        expires_after_seconds: 600,
        length: 50
      })

    now = System.os_time(:second)

    from(otp in Nopass.Schema.OneTimePassword,
      where: otp.password == ^one_time_password and otp.expires_at >= ^now
    )
    |> Nopass.Repo.one()
    |> case do
      nil ->
        {:error, :expired_or_missing}

      otp_record ->
        Nopass.Repo.delete(otp_record)

        login_token_identity =
          if is_function(login_token_params.login_token_identity) do
            login_token_params.login_token_identity.(otp_record.identity)
          else
            login_token_params.login_token_identity
          end

        insert_login_token(login_token_identity, login_token_params.expires_after_seconds, login_token_params.length)
    end
  end

  @doc ~S"""
  Verifies a login token.

  Returns:
  `{:ok, entity_name}` if the supplied token is valid.
  `{:error, :expired_or_missing}` if the supplied token is not valid.

  Parameters:
     `login_token`: the login token to verify.

  ## Examples

      iex> one_time_password = Nopass.new_one_time_password("luigi@mansion")
      iex> {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password)
      iex> Nopass.verify_login_token(login_token)
      {:ok, "luigi@mansion"}
      iex> Nopass.verify_login_token("bad login token")
      {:error, :expired_or_missing}
  """
  def verify_login_token(login_token) do
    now = System.os_time(:second)

    from(lt in Nopass.Schema.LoginToken,
      where:
        lt.login_token == ^login_token and
          lt.expires_at >= ^now
    )
    |> Nopass.Repo.one()
    |> case do
      nil ->
        {:error, :expired_or_missing}

      login_token_record ->
        {:ok, login_token_record.identity}
    end
  end

  @doc ~S"""
  Deletes a login token.

  Once the login token has been deleted, it can no longer be successfully verified.

  Returns:
  `:ok`

  Parameters:
     `login_token`: the login token to delete.

  ## Examples

      iex> one_time_password = Nopass.new_one_time_password("luigi@mansion")
      iex> {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password)
      iex> Nopass.verify_login_token(login_token)
      {:ok, "luigi@mansion"}
      iex> Nopass.delete_login_token(login_token)
      :ok
      iex> Nopass.verify_login_token(login_token)
      {:error, :expired_or_missing}
      iex> Nopass.delete_login_token("no such login token")
      :ok
  """
  def delete_login_token(login_token) do
    from(lt in Nopass.Schema.LoginToken,
      where: lt.login_token == ^login_token
    )
    |> Nopass.Repo.delete_all()

    :ok
  end

  def test_use_only_find_otp_containing_identity_string(identity_substring) do
    from(otp in Nopass.Schema.OneTimePassword,
      where: like(otp.identity, ^"%#{identity_substring}%")
    )
    |> Nopass.Repo.one()
  end

  def test_use_only_find_login_token_containing_identity_string(identity_substring) do
    from(otp in Nopass.Schema.LoginToken,
      where: like(otp.identity, ^"%#{identity_substring}%")
    )
    |> Nopass.Repo.one()
  end

  defp insert_login_token(entity, expires_after_seconds, length) do
    login_token = "lt" <> Nanoid.generate(length, @password_dictionary)
    expires_at = System.os_time(:second) + expires_after_seconds

    {:ok, _} =
      %Nopass.Schema.LoginToken{
        identity: entity,
        login_token: login_token,
        expires_at: expires_at
      }
      |> Nopass.Repo.insert()

    {:ok, login_token}
  end
end
