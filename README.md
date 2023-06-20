# Nopass

This package simplifies implementing passwordless authentication experiences.

In a common passwordless experience, your application sends a magic code (also known as "one-time password") to a user's mailbox, which the user then presents back to your application in order to obtain a longer-term login token. Once the user obtains a login token, they submit it when interacting with your application as a proof of their identity.

This package provides functions for managing magic codes ("one-time passwords") and login tokens.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `nopass` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nopass, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/nopass>.

