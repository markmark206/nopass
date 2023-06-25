defmodule NopassTest do
  use ExUnit.Case, async: true
  doctest Nopass

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Nopass.Repo)
  end

  test "one-time password and login token: the life of" do
    entity = "luigi"

    one_time_password = Nopass.new_one_time_password(entity)
    assert_looks_like_a_one_time_password(one_time_password)

    {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token("not a good password")

    {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password)
    assert_looks_like_a_login_token(login_token)

    # A one time password can only be used once.
    {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token(one_time_password)

    # I can login with a good login token, but, ofc, not a bad login token.
    {:ok, ^entity} = Nopass.verify_login_token(login_token)
    {:error, :expired_or_missing} = Nopass.verify_login_token("nosuchtoken")

    # Once I log out (delete the login token), I can no longer login.
    {:ok, ^entity} = Nopass.verify_login_token(login_token)
    :ok = Nopass.delete_login_token(login_token)
    {:error, :expired_or_missing} = Nopass.verify_login_token(login_token)

    # Deleting an already deleted or simply bad login token should be fine.
    :ok = Nopass.delete_login_token(login_token)
    :ok = Nopass.delete_login_token("non such")
  end

  test "try to use an expired one-time password" do
    one_time_password = Nopass.new_one_time_password("mario", expires_after_seconds: 1)
    assert_looks_like_a_one_time_password(one_time_password)
    Process.sleep(2000)
    {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token(one_time_password)
  end

  test "try to use an expired login token" do
    entity = "princess peach"

    one_time_password = Nopass.new_one_time_password(entity)
    assert_looks_like_a_one_time_password(one_time_password)

    {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password, expires_after_seconds: 1)

    assert_looks_like_a_login_token(login_token)
    {:ok, ^entity} = Nopass.verify_login_token(login_token)
    Process.sleep(2000)
    {:error, :expired_or_missing} = Nopass.verify_login_token(login_token)
  end

  test "verify a one-time password a bunch of times" do
    entity = "wario"
    one_time_password = Nopass.new_one_time_password(entity)
    {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password)

    1..1000
    |> Enum.each(fn _ ->
      {:ok, ^entity} = Nopass.verify_login_token(login_token)
    end)

    :ok = Nopass.delete_login_token(login_token)

    1..1000
    |> Enum.each(fn _ ->
      {:error, :expired_or_missing} = Nopass.verify_login_token(login_token)
    end)
  end

  defp assert_looks_like_a_one_time_password(one_time_password) do
    assert one_time_password
    assert String.length(one_time_password) == 23
    assert String.starts_with?(one_time_password, "otp")
  end

  defp assert_looks_like_a_login_token(login_token) do
    assert login_token
    assert String.length(login_token) == 52
    assert String.starts_with?(login_token, "lt")
  end
end
