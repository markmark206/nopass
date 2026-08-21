# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nopass is a published Hex library (`nopass`) for passwordless authentication: it issues one-time
passwords ("magic codes"), trades them for longer-lived login tokens, and stores both in PostgreSQL
so tokens can be revoked.

## Commands

Prefer Makefile targets over direct mix commands:

```bash
make all           # build, db-setup, format-check, lint, test — same as CI
make build         # mix compile --force --warnings-as-errors, then mix docs
make db-setup      # mix ecto.create && mix ecto.migrate
make format        # mix format
make format-check  # mix format --check-formatted
make lint          # mix credo, mix hex.outdated (non-fatal), mix hex.audit
make test          # mix test --trace --cover --warnings-as-errors
make build-docs    # mix docs only
```

Direct mix commands (when Makefile targets aren't sufficient):

```bash
mix deps.get
mix test test/nopass_test.exs        # single file
mix test test/nopass_test.exs:18     # single test by line
```

`make test` enforces a **90% coverage threshold** (`test_coverage` in `mix.exs`, with `Nopass.Repo`
ignored) and treats warnings as errors — new code without tests will fail the build.

## Database Requirements

- PostgreSQL must be running locally; default connection `postgres:postgres@localhost/nopass_repo`.
- There is a **single `config/config.exs` for all environments**, and it always sets
  `pool: Ecto.Adapters.SQL.Sandbox`. Consumers of the library configure `Nopass.Repo` themselves.
- Migrations run automatically at application start via `{Ecto.Migrator, repos: [Nopass.Repo]}` in
  `lib/nopass/application.ex` — there is no separate migration step for library consumers.

## Architecture

Nearly all logic lives in `lib/nopass.ex`; the rest of the tree is thin.

- **`lib/nopass.ex`** — the entire public API. Two-stage flow:
  `new_one_time_password/2` → `trade_one_time_password_for_login_token/2` → `verify_login_token/2`
  / `find_valid_login_token/1` → `delete_login_token/1`. Also `find_one_time_password/1` (non-consuming
  lookup), `record_access_and_set_metadata/2`, `delete_login_token_by_id/1`,
  `list_login_tokens_for_identity/1`.
- **`lib/schema.ex`** — `Nopass.Schema.OneTimePassword` and `Nopass.Schema.LoginToken`, both built on
  the `Nopass.Schema.Base` `__using__` macro, which forces **integer Unix-epoch-second timestamps**
  (`@timestamps_opts type: :integer, autogenerate: {System, :os_time, [:second]}`). All time
  comparisons in queries are plain integer math against `System.os_time(:second)`; do not introduce
  `DateTime` columns.
- **`lib/nopass/repo.ex`**, **`lib/nopass/application.ex`** — Repo plus the supervisor that starts it
  and runs migrations.

Cross-cutting invariants worth knowing before editing:

- **Tokens are never stored in plaintext.** `hash_token/1` (SHA-256, `Base.url_encode64(padding: false)`)
  is applied on insert and on every lookup. The caller holds the plaintext; the DB column holds the
  hash. Any new query that matches a token must hash the input first.
- **Token prefixes**: OTPs are `"otp" <> Nanoid.generate(...)`, login tokens `"lt" <> ...`, drawn from
  an alphanumeric dictionary defined by `@password_dictionary`.
- **Trading is atomic.** `trade_one_time_password_for_login_token/2` runs inside
  `Nopass.Repo.transaction/1` and uses `delete_all` with `select: otp` so consuming the OTP and issuing
  the token cannot race; the expired/missing path calls `Nopass.Repo.rollback(:expired_or_missing)`,
  while insert failures roll back with the underlying reason. Preserve this
  delete-then-insert-in-transaction shape.
- **`login_token_identity`** may be either a literal value or a 1-arity function applied to the OTP's
  identity — both branches must keep working.

### Expired-record garbage collection

There is no scheduled job. `new_one_time_password/2` probabilistically calls `purge_expired_records/0`
(`@doc false`, but public so tests can drive it), controlled by application env:

- `:cleanup_probability` (default `200`) — purge runs when `:rand.uniform(probability) == 1`; set to
  `0` to disable GC entirely.
- `:cleanup_grace_period_seconds` (default `86_400`) — only records expired longer than this are deleted.

## Testing

- `test/nopass_test.exs` uses `async: true` with `Ecto.Adapters.SQL.Sandbox` (`:manual` mode set in
  `test/test_helper.exs`, checked out per test in `setup`).
- The file starts with `doctest Nopass`, so **the `## Examples` blocks in `lib/nopass.ex` moduledocs
  and function docs are executed as tests against a real database.** Editing those docs can break the
  suite, and new public functions should carry runnable examples.
- `Nopass.test_use_only_find_otp_containing_identity_string/1` and
  `Nopass.test_use_only_find_login_token_containing_identity_string/1` are defined in `lib/nopass.ex`
  (not in the test file) and exist purely to assert DB state from tests.
- Tests namespace identities with a per-test `test_id()` suffix so parallel runs don't collide.

## Compatibility

`mix.exs` declares `elixir: "~> 1.15"` and CI (`.github/workflows/validate.yml`) runs `make all`
against an Elixir 1.15 / 1.19 / 1.20 × OTP 26 / 27 / 28 matrix. Local development pins Elixir 1.20.2 /
Erlang 28.5 via `.tool-versions`. Avoid syntax or stdlib functions newer than Elixir 1.15.

Formatting is `line_length: 120` (`.formatter.exs`).

## Code Comments

Lean toward minimalism: add a comment only when it genuinely helps the reader
understand the code it sits on.

- Don't explain historical reasons or the history of changes — that's what git is for.
- Don't restate behavior owned by another part of the code. Such comments are redundant
  on arrival and wrong once that code changes.
- Exception: do comment a non-obvious cross-module constraint, such as the
  hash-before-lookup rule or the atomicity of the OTP-to-token trade.

This applies to inline `#` comments. `@doc` and `@moduledoc` are different — they are the
published HexDocs API reference, and their `## Examples` blocks run as doctests, so keep
them thorough.

## Scratch Scripts

For quick throwaway scripts, prefer Elixir (`.exs`) over Python or shell — the toolchain is
already Elixir, and asdf pins no Python here, so `python3` is likely to fail outright.

Run them with `mix run scratch/foo.exs` (plain `elixir scratch/foo.exs` loads neither the
deps nor the OTP app, so `Nopass` won't be defined). For interactive poking, use
`iex -S mix`.

Scratch scripts talk to the local package database configured in `config/config.exs`. That
config sets the Sandbox pool, but `:manual` mode is only enabled in `test/test_helper.exs`,
so writes from a scratch script persist instead of rolling back — expect leftover state from
earlier runs. No need to perform any clean up – this is just a local db for testing the
package. If you think the cleanup is truly necessary, leave it to the user.

Save scripts under `scratch/` and leave them there when done; no need to delete the files.
The directory is gitignored, so they stay local and out of this published package's tree.
