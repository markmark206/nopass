.PHONY: \
	all \
	build \
	build-docs \
	db-setup \
	format \
	format-check \
	lint \
	test

all: build db-setup format-check lint test

build:
	mix compile --force --warnings-as-errors
	mix docs --proglang elixir

build-docs:
	mix docs --proglang elixir

db-setup:
	mix ecto.create
	mix ecto.migrate

format:
	mix format

format-check:
	mix format --check-formatted

lint:
	mix credo
	mix hex.outdated || true

test:
	mix test --trace --cover --warnings-as-errors
