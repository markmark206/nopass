.PHONY: \
	all \
	build \
	db-setup \
	format \
	format-check \
	lint \
	test

all: build db-setup format-check lint test

build:
	mix compile --force --warnings-as-errors

format:
	mix format

format-check:
	mix format --check-formatted

lint:
	mix credo

db-setup:
	mix ecto.create
	mix ecto.migrate

test:
	mix test --trace --cover --warnings-as-errors
