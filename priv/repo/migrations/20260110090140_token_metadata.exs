defmodule Nopass.Repo.Migrations.TokenMetadata do
  use Ecto.Migration

  def change do
    alter table(:login_tokens) do
      add(:last_verified_at, :bigint)
      add(:metadata, :map)
    end

    create(index(:login_tokens, [:identity], name: :login_tokens_identity_index))
  end
end
