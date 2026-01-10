# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nopass is an Elixir library for passwordless authentication. It manages one-time passwords (OTPs) and login tokens using PostgreSQL for storage.

## Commands

Prefer Makefile targets over direct mix commands:

```bash
# Run everything (build, db-setup, format-check, lint, test)
make all

# Run tests with coverage and warnings-as-errors
make test

# Run linter
make lint

# Format code
make format

# Check formatting without modifying
make format-check

# Compile with warnings-as-errors
make build

# Setup database
make db-setup
```

Direct mix commands (use when Makefile targets aren't sufficient):

```bash
# Install dependencies
mix deps.get

# Run a single test file
mix test test/nopass_test.exs

# Run a specific test by line number
mix test test/nopass_test.exs:18
```

## Database Requirements

- PostgreSQL must be running locally
- Default connection: `postgres:postgres@localhost/nopass_repo`
- Configuration is in `config/config.exs`
- Migrations run automatically on application start via `Ecto.Migrator`

## Architecture

The library has a simple structure centered around the `Nopass` module:

- **`lib/nopass.ex`** - Main API module with public functions:
  - `new_one_time_password/2` - Creates an OTP (prefixed with "otp")
  - `trade_one_time_password_for_login_token/2` - Exchanges valid OTP for login token (prefixed with "lt")
  - `find_valid_login_token/1` - Looks up a login token and returns the record (or nil)
  - `record_access_and_set_metadata/2` - Records access time and metadata for a token
  - `delete_login_token/1` - Revokes a login token by token string
  - `delete_login_token_by_id/1` - Revokes a login token by database ID
  - `list_login_tokens_for_identity/1` - Lists all active tokens for an identity

- **`lib/schema.ex`** - Ecto schemas for `one_time_passwords` and `login_tokens` tables. Both use integer timestamps (Unix epoch seconds).

- **`lib/nopass/repo.ex`** - Ecto Repo using PostgreSQL adapter

- **`lib/nopass/application.ex`** - OTP application that starts the Repo and runs migrations

- Tokens are stored as SHA-256 hashes in the database. Users receive plaintext tokens; hashing happens transparently on storage and lookup.

## Testing

Tests use Ecto SQL Sandbox for isolation (`async: true` is enabled). The test file contains helper functions `test_use_only_find_otp_containing_identity_string/1` and `test_use_only_find_login_token_containing_identity_string/1` for verifying database state. Test coverage threshold is 97%.
