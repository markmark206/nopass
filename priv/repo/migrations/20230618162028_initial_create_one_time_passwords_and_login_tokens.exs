defmodule Nopass.Repo.Migrations.InitialCreateOneTimePasswordsAndLoginTokens do
  use Ecto.Migration

  def change do
    create table(:one_time_passwords) do
      add(:identity, :string)
      add(:password, :string)
      add(:expires_at, :bigint)
      timestamps(type: :bigint)
    end

    create(
      unique_index(
        :one_time_passwords,
        [:password],
        name: :unique_one_time_password_index
      )
    )

    create(index(:one_time_passwords, [:password, :expires_at], name: :one_time_passwords_expires_at_index))

    create table(:login_tokens) do
      add(:identity, :string)
      add(:login_token, :string)
      add(:expires_at, :bigint)
      timestamps(type: :bigint)
    end

    create(
      unique_index(
        :login_tokens,
        [:login_token],
        name: :unique_login_tokens_index
      )
    )

    create(index(:login_tokens, [:login_token, :expires_at], name: :login_tokens_expires_at_index))
  end
end
