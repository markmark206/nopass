defmodule NopassTest do
  use ExUnit.Case, async: true
  doctest Nopass

  defp random_string() do
    for _ <- 1..10, into: "", do: <<Enum.random(?a..?z)>>
  end

  defp test_id() do
    "#{System.os_time(:second)}_#{random_string()}"
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Nopass.Repo)
    {:ok, %{test_id: test_id()}}
  end

  test "one-time password and login token: the life of", %{test_id: test_id} do
    entity = "luigi_#{test_id}"

    one_time_password = Nopass.new_one_time_password(entity)
    assert_looks_like_a_one_time_password(one_time_password)

    assert nil != Nopass.test_use_only_find_otp_containing_identity_string(entity)

    {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token("not a good password")

    assert nil == Nopass.test_use_only_find_login_token_containing_identity_string(entity)
    {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password)
    assert_looks_like_a_login_token(login_token)
    assert nil == Nopass.test_use_only_find_otp_containing_identity_string(entity)
    assert nil != Nopass.test_use_only_find_login_token_containing_identity_string(entity)

    # A one time password can only be used once.
    {:error, :expired_or_missing} = Nopass.trade_one_time_password_for_login_token(one_time_password)

    # I can login with a good login token, but, ofc, not a bad login token.
    %Nopass.Schema.LoginToken{identity: ^entity} = Nopass.find_valid_login_token(login_token)
    nil = Nopass.find_valid_login_token("nosuchtoken")

    # Once I log out (delete the login token), I can no longer login.
    %Nopass.Schema.LoginToken{identity: ^entity} = Nopass.find_valid_login_token(login_token)
    :ok = Nopass.delete_login_token(login_token)
    nil = Nopass.find_valid_login_token(login_token)
    assert nil == Nopass.test_use_only_find_login_token_containing_identity_string(entity)

    # Deleting an already deleted or simply bad login token should be fine.
    :ok = Nopass.delete_login_token(login_token)
    :ok = Nopass.delete_login_token("nonesuch")
  end

  test "login token identity, value" do
    one_time_password = Nopass.new_one_time_password("luigi")

    {:ok, login_token} =
      Nopass.trade_one_time_password_for_login_token(
        one_time_password,
        login_token_identity: "mario"
      )

    %Nopass.Schema.LoginToken{identity: "mario"} = Nopass.find_valid_login_token(login_token)
  end

  test "login token identity, function" do
    one_time_password = Nopass.new_one_time_password("luigi")

    f_prepend_with_yay = fn x -> "yay" <> x end

    {:ok, login_token} =
      Nopass.trade_one_time_password_for_login_token(
        one_time_password,
        login_token_identity: f_prepend_with_yay
      )

    %Nopass.Schema.LoginToken{identity: "yayluigi"} = Nopass.find_valid_login_token(login_token)
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
    %Nopass.Schema.LoginToken{identity: ^entity} = Nopass.find_valid_login_token(login_token)
    Process.sleep(2000)
    nil = Nopass.find_valid_login_token(login_token)
  end

  test "find a login token a bunch of times" do
    entity = "wario"
    one_time_password = Nopass.new_one_time_password(entity)
    {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password)

    1..1000
    |> Enum.each(fn _ ->
      %Nopass.Schema.LoginToken{identity: ^entity} = Nopass.find_valid_login_token(login_token)
    end)

    :ok = Nopass.delete_login_token(login_token)

    1..1000
    |> Enum.each(fn _ ->
      nil = Nopass.find_valid_login_token(login_token)
    end)
  end

  test "record_access_and_set_metadata updates last_verified_at and metadata", %{test_id: test_id} do
    entity = "bowser_#{test_id}"
    metadata = %{"ip_address" => "1.2.3.4", "user_agent" => "test browser"}

    one_time_password = Nopass.new_one_time_password(entity)
    {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password)

    # Before recording access, last_verified_at should be nil
    [%Nopass.Schema.LoginToken{} = token_before] = Nopass.list_login_tokens_for_identity(entity)
    assert token_before.last_verified_at == nil
    assert token_before.metadata == nil
    assert is_binary(token_before.login_token)

    # Find the token and record access with metadata
    record = Nopass.find_valid_login_token(login_token)
    :ok = Nopass.record_access_and_set_metadata(record, metadata)

    # After recording, last_verified_at and metadata should be set
    [%Nopass.Schema.LoginToken{} = token_after] = Nopass.list_login_tokens_for_identity(entity)
    assert token_after.last_verified_at != nil
    assert token_after.metadata == metadata
  end

  test "find_valid_login_token does not update the record", %{test_id: test_id} do
    entity = "toad_#{test_id}"

    one_time_password = Nopass.new_one_time_password(entity)
    {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(one_time_password)

    [%Nopass.Schema.LoginToken{} = token_before] = Nopass.list_login_tokens_for_identity(entity)

    # Find without recording access
    %Nopass.Schema.LoginToken{identity: ^entity} = Nopass.find_valid_login_token(login_token)

    # Record should not be updated
    [%Nopass.Schema.LoginToken{} = token_after] = Nopass.list_login_tokens_for_identity(entity)
    assert token_after.last_verified_at == token_before.last_verified_at
    assert token_after.metadata == token_before.metadata
  end

  test "list_login_tokens_for_identity returns correct tokens", %{test_id: test_id} do
    entity = "yoshi_#{test_id}"

    # Create two tokens for the same identity
    otp1 = Nopass.new_one_time_password(entity)
    {:ok, _login_token1} = Nopass.trade_one_time_password_for_login_token(otp1)

    otp2 = Nopass.new_one_time_password(entity)
    {:ok, _login_token2} = Nopass.trade_one_time_password_for_login_token(otp2)

    tokens = Nopass.list_login_tokens_for_identity(entity)
    assert length(tokens) == 2

    # Verify structure of returned tokens
    Enum.each(tokens, fn %Nopass.Schema.LoginToken{} = token ->
      assert is_integer(token.id)
      assert is_integer(token.inserted_at)
      assert is_integer(token.expires_at)
      assert token.identity == entity
      assert is_binary(token.login_token)
    end)
  end

  test "list_login_tokens_for_identity excludes expired tokens", %{test_id: test_id} do
    entity = "dk_#{test_id}"

    # Create an expired token
    otp = Nopass.new_one_time_password(entity)
    {:ok, _login_token} = Nopass.trade_one_time_password_for_login_token(otp, expires_after_seconds: 1)

    # Initially should have one token
    assert length(Nopass.list_login_tokens_for_identity(entity)) == 1

    # Wait for expiration
    Process.sleep(2000)

    # Should return empty list after expiration
    assert Nopass.list_login_tokens_for_identity(entity) == []
  end

  test "list_login_tokens_for_identity returns empty list for unknown identity" do
    assert Nopass.list_login_tokens_for_identity("unknown_identity_xyz") == []
  end

  test "delete_login_token_by_id deletes the correct token", %{test_id: test_id} do
    entity = "diddy_#{test_id}"

    otp = Nopass.new_one_time_password(entity)
    {:ok, login_token} = Nopass.trade_one_time_password_for_login_token(otp)

    [%Nopass.Schema.LoginToken{} = token] = Nopass.list_login_tokens_for_identity(entity)

    :ok = Nopass.delete_login_token_by_id(token.id)

    # Token should no longer be valid
    nil = Nopass.find_valid_login_token(login_token)
    assert Nopass.list_login_tokens_for_identity(entity) == []
  end

  test "delete_login_token_by_id returns :ok even if ID doesn't exist" do
    :ok = Nopass.delete_login_token_by_id(999_999_999)
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
