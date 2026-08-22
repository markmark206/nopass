# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nopass is a library (`nopass`) for passwordless authentication: it issues one-time
passwords ("magic codes"), trades them for longer-lived login tokens, and stores both in a relational
database so tokens can be revoked. It is distributed via git tag, not published on Hex — the
`package:` block in `mix.exs` is publish-ready but has never been exercised.

## Commands

Prefer Makefile targets over direct mix commands:

```bash
make all           # build, db-setup, format-check, lint, test — same as CI
make build         # mix compile --force --warnings-as-errors, then mix docs
make db-setup      # mix ecto.create && mix ecto.migrate
make format        # mix format
make format-check  # mix format --check-formatted
make lint          # mix credo, mix hex.outdated (non-fatal), mix hex.audit
make test          # force-recompile MIX_ENV=test, then mix test --trace --cover --warnings-as-errors
make test-postgres # make test against Postgres
make test-sqlite   # make test against SQLite
make test-adapters # both of the above, in sequence
make build-docs    # mix docs only
```

`make test` runs against whichever adapter `NOPASS_ADAPTER` names (Postgres by default). The named
per-adapter targets exist so no one has to know the variable. Postgres legs need a local PostgreSQL
server; SQLite legs need nothing installed.

Direct mix commands (when Makefile targets aren't sufficient):

```bash
mix deps.get
mix test test/nopass_test.exs        # single file
mix test test/nopass_test.exs:18     # single test by line
```

`make test` enforces a **90% coverage threshold** (`test_coverage` in `mix.exs`, with `Nopass.Repo`
ignored) and treats warnings as errors — new code without tests will fail the build.

Set `NOPASS_ADAPTER=sqlite` on any target to run against SQLite instead of Postgres
(`NOPASS_ADAPTER=sqlite make all`). The adapter is baked in at compile time, so flipping it requires a
recompile: `make build` forces one for `MIX_ENV=dev` and `make test` forces one for `MIX_ENV=test`
(they use separate build directories, so both are needed). A bare `mix test` or `mix run` after a flip
raises a compile-env mismatch instead of silently using the old adapter — pass the same
`NOPASS_ADAPTER` you last built with, or run a `make` target to resync.

The Makefile sets `.NOTPARALLEL:` because all targets share one `_build` tree; without it `make -j`
would let two adapter legs recompile `MIX_ENV=test` over each other.

## Database Requirements

- Two adapters are supported, selected by the `NOPASS_ADAPTER` env var (`postgres`, the default, or
  `sqlite`). `Nopass.Repo` resolves its adapter through `Application.compile_env(:nopass, :adapter,
  Ecto.Adapters.Postgres)`; Ecto requires the adapter at compile time, so this cannot be runtime config.
- For the Postgres default, PostgreSQL must be running locally; default connection
  `postgres:postgres@localhost/nopass_repo`. For `sqlite`, a `nopass_repo.db` file is created at the
  repo root.
- There is a **single `config/config.exs` for all environments**; it branches on adapter, not on
  environment, and always sets `pool: Ecto.Adapters.SQL.Sandbox`. Consumers of the library configure
  `Nopass.Repo` themselves. `config.exs` deliberately leaves `:adapter` unset on the Postgres branch,
  so those runs exercise the same default a consumer who configures nothing gets.
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
- `ecto_sqlite3` does not support the async sandbox, so `make test` passes `--max-cases 1` when
  `NOPASS_ADAPTER=sqlite`. This is a no-op while `test/nopass_test.exs` is the only test module, since
  ExUnit parallelizes across modules rather than within one.
- The "defaults to the Postgres adapter" test is wrapped in an `NOPASS_ADAPTER` check, since the
  adapter legitimately differs on the SQLite legs.

## Compatibility

`mix.exs` declares `elixir: "~> 1.17"` (the floor comes from `ecto_sqlite3`, which requires it) and CI
(`.github/workflows/validate.yml`) runs `make all` against an Elixir 1.19 / 1.20 × OTP 27 / 28 ×
adapter matrix, plus two Elixir 1.17.3 legs that pin the declared floor. Local development pins Elixir
1.20.2 / Erlang 28.5 via `.tool-versions`. Avoid syntax or stdlib functions newer than Elixir 1.17.

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
