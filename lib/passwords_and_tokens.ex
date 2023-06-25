defmodule Nopass.PasswordsAndTokens do
  import Ecto.Query
  require Logger

  @password_dictionary Enum.to_list(?a..?z) ++ Enum.to_list(?A..?Z) ++ Enum.to_list(?0..?9)
  @one_year_ish_in_seconds 60 * 60 * 24 * 365
  @otp_expires_after_default @one_year_ish_in_seconds
  @one_time_password_length_default 20
  @login_token_length_default 30

  # expires_after_seconds \\ 600, length \\ @one_time_password_length_default) do
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

  defp insert_login_token(entity, expires_after, length) do
    login_token = "lt" <> Nanoid.generate(length, @password_dictionary)
    expires_at = System.os_time(:second) + @one_year_ish_in_seconds

    {:ok, _} =
      %Nopass.Schema.LoginToken{
        identity: entity,
        login_token: login_token,
        expires_at: expires_at
      }
      |> Nopass.Repo.insert()

    {:ok, login_token}
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
end
