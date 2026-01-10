# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nopass is an Elixir library for passwordless authentication. It manages one-time passwords (OTPs) and login tokens using PostgreSQL for storage.

## Commands

```bash
# Install dependencies
mix deps.get

# Create and migrate database (requires PostgreSQL running locally)
mix ecto.create
mix ecto.migrate

# Run tests (requires database to be set up)
mix test

# Run a single test file
mix test test/nopass_test.exs

# Run a specific test by line number
mix test test/nopass_test.exs:18

# Run linter
mix credo

# Run tests with coverage
mix test --cover
```

## Database Requirements

- PostgreSQL must be running locally
- Default connection: `postgres:postgres@localhost/nopass_repo`
- Configuration is in `config/config.exs`
- Migrations run automatically on application start via `Ecto.Migrator`

## Architecture

The library has a simple structure centered around the `Nopass` module:

- **`lib/nopass.ex`** - Main API module with four public functions:
  - `new_one_time_password/2` - Creates an OTP (prefixed with "otp")
  - `trade_one_time_password_for_login_token/2` - Exchanges valid OTP for login token (prefixed with "lt")
  - `verify_login_token/1` - Validates a login token and returns identity
  - `delete_login_token/1` - Revokes a login token

- **`lib/schema.ex`** - Ecto schemas for `one_time_passwords` and `login_tokens` tables. Both use integer timestamps (Unix epoch seconds).

- **`lib/nopass/repo.ex`** - Ecto Repo using PostgreSQL adapter

- **`lib/nopass/application.ex`** - OTP application that starts the Repo and runs migrations

- Tokens are stored as SHA-256 hashes in the database. Users receive plaintext tokens; hashing happens transparently on storage and lookup.

## Testing

Tests use Ecto SQL Sandbox for isolation (`async: true` is enabled). The test file contains helper functions `test_use_only_find_otp_containing_identity_string/1` and `test_use_only_find_login_token_containing_identity_string/1` for verifying database state. Test coverage threshold is 100%.
