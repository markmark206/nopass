defmodule NopassTest do
  use ExUnit.Case, async: true
  doctest Nopass.PasswordsAndTokens

  alias Nopass.PasswordsAndTokens

  describe "passwords and tokens" do
    test "new otp" do
      entity = "luigi"

      otp = PasswordsAndTokens.new_one_time_password(entity)
      assert_looks_like_a_one_time_password(otp)
      # assert String.length(otp) == 20

      {:error, :expired_or_missing} = PasswordsAndTokens.trade_one_time_password_for_login_token("not a good password")

      {:ok, login_token} = PasswordsAndTokens.trade_one_time_password_for_login_token(otp)
      assert_looks_like_a_login_token(login_token)

      # A one time password can only be used once.
      {:error, :expired_or_missing} = PasswordsAndTokens.trade_one_time_password_for_login_token(otp)

      # I can login with a good login token, but, ofc, not a bad login token.
      {:ok, ^entity} = PasswordsAndTokens.verify_login_token(login_token)
      {:error, :expired_or_missing} = PasswordsAndTokens.verify_login_token("nosuchtoken")

      # Once I log out (delete the login token), I can no longer login.
      {:ok, ^entity} = PasswordsAndTokens.verify_login_token(login_token)
      :ok = PasswordsAndTokens.delete_login_token(login_token)
      {:error, :expired_or_missing} = PasswordsAndTokens.verify_login_token(login_token)

      # Deleting an already deleted or simply bad login token should be fine.
      :ok = PasswordsAndTokens.delete_login_token(login_token)
      :ok = PasswordsAndTokens.delete_login_token("non such")
    end

    test "try to use an expired otp" do
      one_time_password = PasswordsAndTokens.new_one_time_password("mario", expires_after_seconds: 1)
      assert_looks_like_a_one_time_password(one_time_password)
      Process.sleep(2000)
      {:error, :expired_or_missing} = PasswordsAndTokens.trade_one_time_password_for_login_token(one_time_password)
    end

    test "try to use an expired login token" do
      entity = "princess peach"

      one_time_password = PasswordsAndTokens.new_one_time_password(entity)
      assert_looks_like_a_one_time_password(one_time_password)

      {:ok, login_token} =
        PasswordsAndTokens.trade_one_time_password_for_login_token(one_time_password, expires_after_seconds: 1)

      assert_looks_like_a_login_token(login_token)
      {:ok, ^entity} = PasswordsAndTokens.verify_login_token(login_token)
      Process.sleep(2000)
      {:error, :expired_or_missing} = PasswordsAndTokens.verify_login_token(login_token)
    end

    test "verify a one-time password a bunch of times" do
      entity = "wario"
      otp = PasswordsAndTokens.new_one_time_password(entity)
      {:ok, login_token} = PasswordsAndTokens.trade_one_time_password_for_login_token(otp)

      1..1000
      |> Enum.each(fn _ ->
        {:ok, ^entity} = PasswordsAndTokens.verify_login_token(login_token)
      end)

      :ok = PasswordsAndTokens.delete_login_token(login_token)

      1..1000
      |> Enum.each(fn _ ->
        {:error, :expired_or_missing} = PasswordsAndTokens.verify_login_token(login_token)
      end)
    end
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
