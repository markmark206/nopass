.PHONY: \
	all \
	build \
	format \
	format-check \
	lint \
	test

all: build format-check lint test

build:
	mix compile --force --warnings-as-errors

format:
	mix format

format-check:
	mix format --check-formatted

lint:
	mix credo

test:
	mix test --trace --cover --warnings-as-errors


