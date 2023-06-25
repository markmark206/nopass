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

db-setup:
	mix ecto.create
	mix ecto.migrate

format:
	mix format

format-check:
	mix format --check-formatted

lint:
	mix credo

test:
	mix test --trace --cover --warnings-as-errors
