defmodule Nopass.PasswordsAndTokens do
  @moduledoc """
  This module implements the logic neeeded for implementing passwordless authentication, which relies on magic codes (aka "one-time passwords") and login tokens.

  This passwordless authentication sequence involves your application sending a one-time password to the user's mailbox.
  The user, then, asks your application to trade the one-time password for a more long-term login token.
  After your application issues the login token to the user, the user uses the login token to prove their identity during future interactions with your applications.

  This module simplifies implementing this sequence, by providing the following functions:
  1. `new_one_time_password()`: generates a new one-time password,
  2. `trade_one_time_password_for_login_token()`: trades a valid one-time password for a login token,
  3. `verify_login_token()`: verifies a login token,
  4. `delete_login_token()`: deletes a login token.
  """

  import Ecto.Query
  require Logger

  @password_dictionary Enum.to_list(?a..?z) ++ Enum.to_list(?A..?Z) ++ Enum.to_list(?0..?9)

  @doc ~S"""
  Generates a one-time password for an entity.

  Parameters:
     `entity`: the entity (e.g. email address) for which you are generating the one-time password
     `expires`_after_seconds: the lifetime of the generated one-time passwords after which the password expires. Optional, default: 600
     `length`: the length of the one-time password. Optional, default: 20

  ## Examples

      iex> Nopass.PasswordsAndTokens.new_one_time_password("luigi@mansion", after_seconds: 900, length: 30)

  """

  def new_one_time_password(entity, opts \\ []) do
    params =
      Enum.into(opts, %{
        expires_after_seconds: 600,
        length: 20
      })

    one_time_password = "otp" <> Nanoid.generate(params.length, @password_dictionary)
    expires_at = System.os_time(:second) + params.expires_after_seconds

    %Nopass.Schema.OneTimePassword{
      identity: entity,
      password: one_time_password,
      expires_at: expires_at
    }
    |> Nopass.Repo.insert!()

    one_time_password
  end

  def trade_one_time_password_for_login_token(otp, opts \\ []) do
    params =
      Enum.into(opts, %{
        expires_after_seconds: 600,
        length: 50
      })

    now = System.os_time(:second)

    from(otp in Nopass.Schema.OneTimePassword,
      where: otp.password == ^otp and otp.expires_at >= ^now
    )
    |> Nopass.Repo.one()
    |> case do
      nil ->
        {:error, :expired_or_missing}

      otp_record ->
        Nopass.Repo.delete(otp_record)
        insert_login_token(otp_record.identity, params.expires_after_seconds, params.length)
    end
  end

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

  def delete_login_token(login_token) do
    from(lt in Nopass.Schema.LoginToken,
      where: lt.login_token == ^login_token
    )
    |> Nopass.Repo.delete_all()

    :ok
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
