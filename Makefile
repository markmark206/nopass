.PHONY: \
	all \
	build \
	build-docs \
	db-setup \
	format \
	format-check \
	lint \
	test \
	test-adapters \
	test-postgres \
	test-sqlite

# The adapter is compile-time and all targets share one _build tree, so concurrent legs
# would clobber each other's MIX_ENV=test compile.
.NOTPARALLEL:

NOPASS_ADAPTER ?= postgres
export NOPASS_ADAPTER

ifeq ($(NOPASS_ADAPTER),sqlite)
TEST_OPTS := --max-cases 1
endif

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
	mix hex.audit

test:
	MIX_ENV=test mix compile --force --warnings-as-errors
	mix test --trace --cover --warnings-as-errors $(TEST_OPTS)

test-postgres:
	$(MAKE) test NOPASS_ADAPTER=postgres

test-sqlite:
	$(MAKE) test NOPASS_ADAPTER=sqlite

test-adapters: test-postgres test-sqlite
