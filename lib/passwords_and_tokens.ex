defmodule Nopass.PasswordsAndTokens do
  import Ecto.Query
  require Logger

  @password_dictionary Enum.to_list(?a..?z) ++ Enum.to_list(?A..?Z) ++ Enum.to_list(?0..?9)
  @one_year_ish_in_seconds 60 * 60 * 24 * 365
  @otp_expires_after_default @one_year_ish_in_seconds
  @one_time_password_length_default 20
  @login_token_length_default 30

  def new_one_time_password(entity, expires_after_seconds \\ 600, length \\ @one_time_password_length_default) do
    one_time_password = Nanoid.generate(length, @password_dictionary)

    password_hash =
      one_time_password
      |> Bcrypt.add_hash()
      |> Map.fetch!(:password_hash)

    expires_at = System.os_time(:second) + expires_after_seconds

    new_one_time_password_record =
      %Nopass.Schema.OneTimePassword{
        identity: entity,
        password_hash: password_hash,
        expires_at: expires_at
      }
      |> Nopass.Repo.insert!()

    {:ok, new_one_time_password_record.id, one_time_password}
  end

  def trade_one_time_password_for_login_token(
        otp_id,
        otp,
        expires_after \\ @one_year_ish_in_seconds,
        length \\ @login_token_length_default
      ) do
    now = System.os_time(:second)

    from(otp in Nopass.Schema.OneTimePassword,
      where:
        otp.id == ^otp_id and
          otp.expires_at >= ^now
    )
    |> Nopass.Repo.one()
    |> case do
      nil ->
        {:error, :expired_or_missing}

      otp_record ->
        if Bcrypt.verify_pass(otp, otp_record.password_hash) do
          Nopass.Repo.delete(otp_record)
          insert_login_token(otp_record.identity, expires_after, length)
        else
          {:error, :expired_or_missing}
        end
    end
  end

  defp insert_login_token(entity, expires_after, length) do
    login_token = Nanoid.generate(length, @password_dictionary)

    login_token_hash =
      login_token
      |> Bcrypt.add_hash()
      |> Map.fetch!(:password_hash)

    expires_at = System.os_time(:second) + @one_year_ish_in_seconds

    login_token_record =
      %Nopass.Schema.LoginToken{
        identity: entity,
        login_token_hash: login_token_hash,
        expires_at: expires_at
      }
      |> Nopass.Repo.insert!()

    {:ok, login_token_record.id, login_token}
  end

  def verify_login_token(login_token_id, login_token) do
    now = System.os_time(:second)

    from(lt in Nopass.Schema.LoginToken,
      where:
        lt.id == ^login_token_id and
          lt.expires_at >= ^now
    )
    |> Nopass.Repo.one()
    |> case do
      nil ->
        {:error, :expired_or_missing}

      login_token_record ->
        {uSecs, result} =
          :timer.tc(fn ->
            if Bcrypt.verify_pass(login_token, login_token_record.login_token_hash) do
              {:ok, login_token_record.identity}
            else
              {:error, :expired_or_missing}
            end
          end)

        Logger.info("bcrypt duration, #{uSecs / 1_000_000}")

        result
    end
  end

  def delete_login_token(login_token_id) do
    from(lt in Nopass.Schema.LoginToken,
      where: lt.id == ^login_token_id
    )
    |> Nopass.Repo.delete_all()

    :ok
  end
end
