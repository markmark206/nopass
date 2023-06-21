defmodule Nopass do
  import Ecto.Query
  require Logger

  @moduledoc """
  Documentation for `Nopass`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Nopass.hello()
      :world

  """
  def hello do
    :world
  end

  @password_dictionary Enum.to_list(?a..?z) ++ Enum.to_list(?A..?Z) ++ Enum.to_list(?0..?9)

  # Options:
  # expires_after_seconds \\ 600 (10 minutes)
  # length \\ 20
  # dictionary \\ a..z ++ A..Z ++ 0..9
  def new_one_time_password(entity_id, opts \\ []) do
    Logger.info("generating otp for entity #{entity_id}")

    params =
      Enum.into(opts, %{
        expires_after_seconds: 600,
        length: 20
      })

    password = "otp" <> Nanoid.generate(params.length, @password_dictionary)

    password_hash =
      password
      |> Bcrypt.add_hash()
      |> Map.fetch!(:password_hash)

    expires_at = System.os_time(:second) + params.expires_after_seconds

    %Nopass.Schema.OneTimePassword{
      identity: entity_id,
      password_hash: password_hash,
      expires_at: expires_at
    }
    |> Nopass.Repo.insert!()
    |> IO.inspect(label: :new_otp)

    password
  end

  @one_year_ish_in_seconds 60 * 60 * 24 * 365
  @login_token_length 50

  defp insert_login_token(entity) do
    login_token = "lt" <> Nanoid.generate(@login_token_length, @password_dictionary)
    expires_at = System.os_time(:second) + @one_year_ish_in_seconds

    # TODO: use login token hash.
    %Nopass.Schema.LoginToken{
      identity: entity,
      login_token_hash: Bcrypt.add_hash(login_token),
      expires_at: expires_at
    }
    |> Nopass.Repo.insert!()

    # |> IO.inspect(label: :new_token)

    login_token
  end

  def trade_one_time_password_for_login_token(one_time_password) do
    # TODO: use password hash.
    now = System.os_time(:second)

    from(otp in Nopass.Schema.OneTimePassword,
      where:
        otp.password_hash == ^one_time_password and
          otp.expires_at >= ^now,
      select: otp.identity
    )
    |> Nopass.Repo.delete_all()
    |> case do
      {0, _} ->
        Logger.warning("there are no matching one time passwords")
        {:error, :expired_or_missing}

      {1, [entity]} ->
        Logger.info("found 1 otp record for #{inspect(entity)}")
        login_token = insert_login_token(entity)
        {:ok, entity, login_token}

      {n, [entity | _]} ->
        Logger.warning("found #{n} otp records for #{inspect(entity)}")
        login_token = insert_login_token(entity)
        {:ok, entity, login_token}
    end
  end

  def verify_login_token(login_token) do
    # TODO: hash login tokens
    login_token_hash = login_token
    now = System.os_time(:second)

    from(lt in Nopass.Schema.LoginToken,
      where:
        lt.login_token_hash == ^login_token_hash and
          lt.expires_at >= ^now,
      select: lt.identity
    )
    |> Nopass.Repo.one()
    |> case do
      nil ->
        {:error, :expired_or_missing}

      identity ->
        {:ok, identity}
    end
  end

  def delete_login_token_if_present(login_token) do
    # TODO: hash login token
    login_token_hash = login_token

    from(lt in Nopass.Schema.LoginToken,
      where: lt.login_token_hash == ^login_token_hash
    )
    |> Nopass.Repo.delete_all()

    :ok
  end
end
