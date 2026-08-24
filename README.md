# Nopass

This package simplifies implementing passwordless authentication experiences.

In a common passwordless experience, your application sends a magic code (also known as "one-time password") to a user's mailbox, which the user then presents back to your application in order to obtain a longer-term login token. Once the user obtains a login token, they submit it when interacting with your application as a proof of their identity.

This package provides functions for managing magic codes ("one-time passwords") and login tokens.

## Installation

Nopass is distributed via git, not Hex. Add it to your list of dependencies in `mix.exs`, pinning a tag:

```elixir
def deps do
  [
    {:nopass, git: "https://github.com/markmark206/nopass.git", tag: "0.2.0"}
  ]
end
```

Nopass requires Elixir 1.17 or later.

## Configuration

Nopass is an OTP application: its supervisor starts `Nopass.Repo` and runs its own migrations at
boot. You must configure the repo, or your application will not start. You do **not** add
`Nopass.Repo` to your supervision tree, and you do **not** run its migrations yourself.

PostgreSQL is the default adapter. Configure it as you would any Ecto repo:

```elixir
# config/config.exs
config :nopass, Nopass.Repo,
  database: "my_app_nopass",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"
```

## Using nopass with SQLite

Nopass also runs on SQLite. Because the SQLite adapter is an optional dependency and nopass is
installed from git rather than Hex, you declare the adapter yourself.

### 1. Declare the adapter in `mix.exs`

```elixir
{:nopass, git: "https://github.com/markmark206/nopass.git", tag: "0.2.0"},
{:ecto_sqlite3, ">= 0.17.4 and < 1.0.0"},
{:exqlite, ">= 0.27.0 and < 1.0.0"},
```

Declaring `exqlite` explicitly is not redundant. The `default_transaction_mode` setting below is read
by `exqlite` and was added in its v0.27.0, but `ecto_sqlite3` only requires `exqlite ~> 0.22`. Without
the direct pin, another dependency in your project can hold `exqlite` at 0.22–0.26, where the unknown
option is silently dropped and transactions quietly revert to `:deferred` — no warning, no error, just
weaker behavior under write contention. Since nopass is a git dependency, you inherit no lockfile that
would pin this for you.

These bounds reflect versions current at the time of writing. If a later `ecto_sqlite3` requires
`exqlite ~> 1.0`, the `< 1.0.0` bound will conflict; widen it deliberately rather than dropping it,
since the bound exists to turn a silent misconfiguration into a visible one.

Nopass itself declares only `{:exqlite, ">= 0.27.0", optional: true}`, with no upper bound, and that
asymmetry is deliberate. The lower bound is what prevents the silent revert described above, so nopass
enforces it for everyone. An upper bound inside nopass would be one you cannot widen without patching
nopass or resorting to `override: true`, so that half of the decision is left to you, in the line above
that you control.

Check your Ecto version too: `ecto_sqlite3` 0.24.1 requires `ecto ~> 3.14` and `ecto_sql ~> 3.14`. An
app holding `ecto_sql` at 3.12 or 3.13 will hit a resolution failure and must upgrade Ecto first.

### 2. Select the adapter in compile-time config

```elixir
config :nopass, adapter: Ecto.Adapters.SQLite3
```

This key is read via `Application.compile_env/3`, so it must be set in configuration that is
evaluated at compile time: `config/config.exs`, or an environment file such as `config/dev.exs` that
`config.exs` imports. Setting it in `config/runtime.exs` raises an error about compile-time and
runtime values disagreeing. Only this key is compile-time; the database paths below are ordinary
runtime config.

If you configure the adapter but omit the dependency, compilation fails with a clear message:

```
adapter Ecto.Adapters.SQLite3 was not compiled, ensure it is correct
and it is included as a project dependency
```

Changing this key later requires no manual step. Mix tracks compile-time configuration per
application, so editing your config file makes it recompile nopass on the next build.

That auto-recompile follows from the config *file* changing. If you instead select the adapter from
something Mix cannot see change — reading an environment variable inside `config.exs`, say — nothing
looks stale, and Mix reports a compile-time/runtime mismatch rather than rebuilding. Its own suggested
remedy is `mix deps.clean nopass --build`; `mix deps.compile nopass --force` works too.

### 3. Configure the database

Nopass gets its own database file, separate from your application's.

```elixir
# config/config.exs, alongside the adapter
config :nopass, Nopass.Repo,
  busy_timeout: 5_000,
  default_transaction_mode: :immediate

# config/dev.exs
config :nopass, Nopass.Repo,
  database: Path.expand("../nopass_dev.db", __DIR__),
  pool_size: 5

# config/test.exs
config :nopass, Nopass.Repo,
  database: Path.expand("../nopass_test#{System.get_env("MIX_TEST_PARTITION")}.db", __DIR__),
  pool_size: 5

# config/runtime.exs — paths only, never the adapter
config :nopass, Nopass.Repo,
  database: System.get_env("NOPASS_DATABASE_PATH") || raise("NOPASS_DATABASE_PATH is missing"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
```

`default_transaction_mode: :immediate` is recommended. The `ecto_sqlite3` default, `:deferred`, starts
a transaction as a reader and upgrades it on first write; SQLite cannot safely block on that upgrade
and fails immediately with `SQLITE_BUSY_SNAPSHOT`, which `busy_timeout` does not cover.

You do not need to run `mix ecto.create` — the database file is created on first connection, and
nopass runs its migrations at boot.

### 4. Testing

`ecto_sqlite3` does not support the async Ecto sandbox. Mirror whatever convention your app already
uses for its own SQLite repo:

- **Sandbox `Nopass.Repo` too** — clean per-test isolation, but every test module touching nopass must
  be `async: false`. Add a `Sandbox.start_owner!(Nopass.Repo, ...)` alongside your existing one.
- **Skip the sandbox for `Nopass.Repo`** — point it at a test `.db` file and let rows accumulate. Keeps
  modules `async: true`, and suits suites built around unique per-test data.

### 5. Deployment

Alongside your app's existing database path, set `NOPASS_DATABASE_PATH` (for example
`/data/nopass.db`, on the same volume) and add it to your backup set.

**Single node only.** SQLite permits one writer, and its locking is unsafe across network filesystems,
so nopass on SQLite must not run from more than one node against a shared volume. `busy_timeout` and
`default_transaction_mode` tune contention *within* a node; neither makes multi-node access safe, and
the failure mode is corruption rather than a clean error. If you need to scale horizontally, keep
nopass on PostgreSQL — the default, which needs no adapter configuration at all.

## Upgrading from 0.1.x

- Nopass now requires **Elixir 1.17** or later.
- PostgreSQL users need no changes beyond bumping the git tag: no new dependency, no configuration,
  no migration. The adapter defaults to `Ecto.Adapters.Postgres` when `:adapter` is unset.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) by running
`mix docs`.
