defmodule NopassTest do
  use ExUnit.Case
  doctest Nopass

  test "greets the world" do
    assert Nopass.hello() == :world
  end

  test "generate a one time password for entity" do
    otp = Nopass.generate("luigi")
    assert_looks_like_a_one_time_password(otp)
  end

  test "use an otp to login" do
    entity = "markmark"
    otp = Nopass.generate(entity)
    assert_looks_like_a_one_time_password(otp)
    {:ok, ^entity, login_token} = Nopass.trade_one_time_password_for_login_token(otp)
    assert_looks_like_a_login_token(login_token)
    {:ok, ^entity} = Nopass.verify_login_token(login_token)
  end

  test "try to use an otp twice" do
    entity = "entity1"
    otp = Nopass.generate(entity)
    assert otp
    {:ok, ^entity, login_token} = Nopass.trade_one_time_password_for_login_token(otp)
    {:ok, ^entity} = Nopass.verify_login_token(login_token)
    {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token(otp)
    {:ok, ^entity} = Nopass.verify_login_token(login_token)
  end

  test "try to use an expired otp" do
    otp_expires_in_a_sec = Nopass.generate("mario", expires_after_seconds: 1)
    assert_looks_like_a_one_time_password(otp_expires_in_a_sec)

    Process.sleep(2000)

    {:error, :expired_or_missing} =
      Nopass.trade_one_time_password_for_login_token(otp_expires_in_a_sec)
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
