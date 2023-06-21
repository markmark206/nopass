defmodule NopassTest do
  use ExUnit.Case
  doctest Nopass

  alias Nopass.PasswordsAndTokens

  test "greets the world" do
    assert Nopass.hello() == :world
  end

  describe "passwords and tokens" do
    test "new otp" do
      entity = "luigi"

      {:ok, otp_id, otp} = PasswordsAndTokens.new_one_time_password(entity)
      assert String.length(otp) == 30

      {:ok, login_token_id, login_token} = PasswordsAndTokens.trade_one_time_password_for_login_token(otp_id, otp)
      assert String.length(login_token) == 50

      # A one time password can only be used once.
      {:error, :expired_or_missing} = PasswordsAndTokens.trade_one_time_password_for_login_token(otp_id, otp)

      # I can login with a good login token, but, ofc, not a bad login token.
      {:ok, ^entity} = PasswordsAndTokens.verify_login_token(login_token_id, login_token)
      {:error, :expired_or_missing} = PasswordsAndTokens.verify_login_token(login_token_id, "nosuchtoken")
      {:error, :expired_or_missing} = PasswordsAndTokens.verify_login_token(0, login_token)

      # Once I log out (delete the login token), I can no longer login.
      {:ok, ^entity} = PasswordsAndTokens.verify_login_token(login_token_id, login_token)
      :ok = PasswordsAndTokens.delete_login_token(login_token_id)
      {:error, :expired_or_missing} = PasswordsAndTokens.verify_login_token(login_token_id, login_token)
    end

    test "verify a one-time password a bunch of times" do
      entity = "mario"

      {:ok, otp_id, otp} = PasswordsAndTokens.new_one_time_password(entity)
      {:ok, login_token_id, login_token} = PasswordsAndTokens.trade_one_time_password_for_login_token(otp_id, otp)

      1..100
      |> Enum.each(fn _ ->
        {:ok, ^entity} = PasswordsAndTokens.verify_login_token(login_token_id, login_token)
      end)
    end
  end

  test "generate a one time password for entity" do
    otp = Nopass.new_one_time_password("luigi")
    assert_looks_like_a_one_time_password(otp)
  end

  test "use an otp to login" do
    entity = "markmark"
    otp = Nopass.new_one_time_password(entity)
    assert_looks_like_a_one_time_password(otp)
    {:ok, ^entity, login_token} = Nopass.trade_one_time_password_for_login_token(otp)
    assert_looks_like_a_login_token(login_token)
    {:ok, ^entity} = Nopass.verify_login_token(login_token)
  end

  test "try to use an otp twice" do
    entity = "entity1"
    otp = Nopass.new_one_time_password(entity)
    assert otp
    {:ok, ^entity, login_token} = Nopass.trade_one_time_password_for_login_token(otp)
    {:ok, ^entity} = Nopass.verify_login_token(login_token)
    {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token(otp)
    {:ok, ^entity} = Nopass.verify_login_token(login_token)
  end

  test "try to use an expired otp" do
    otp_expires_in_a_sec = Nopass.new_one_time_password("mario", expires_after_seconds: 1)
    assert_looks_like_a_one_time_password(otp_expires_in_a_sec)

    Process.sleep(2000)

    {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token(otp_expires_in_a_sec)
  end

  test "try to use a bad login token" do
    {:error, :expired_or_missing} = Nopass.verify_login_token("ltnonesuch")
  end

  test "verify a non-existing otp" do
    {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token("otpnonesuch")
  end

  test "try to delete a non-existent login token" do
    :ok = Nopass.delete_login_token_if_present("ltnonesuch")
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
