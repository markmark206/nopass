defmodule Nopass.Repo.Migrations.InitialCreateOneTimePasswordsAndLoginTokens do
  use Ecto.Migration

  def change do
    create table(:one_time_passwords) do
      add(:identity, :string)
      add(:password_hash, :string)
      add(:expires_at, :bigint)
      timestamps(type: :bigint)
    end

    create(
      unique_index(
        :one_time_passwords,
        [:password_hash],
        name: :unique_one_time_password_index
      )
    )

    create(index(:one_time_passwords, [:id, :expires_at], name: :one_time_passwords_id_expires_at_index))
    create(index(:one_time_passwords, [:id], name: :one_time_passwords_id_index))

    create table(:login_tokens) do
      add(:identity, :string)
      add(:login_token_hash, :string)
      add(:expires_at, :bigint)
      timestamps(type: :bigint)
    end

    create(
      unique_index(
        :login_tokens,
        [:login_token_hash],
        name: :unique_login_token_hashes_index
      )
    )

    create(index(:login_tokens, [:id, :expires_at], name: :login_tokens_id_expires_at_index))
    create(index(:login_tokens, [:id], name: :login_tokens_id_index))
  end
end
