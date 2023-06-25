.PHONY: \
	format \
	format-check \
	lint \
	test

format:
	mix format

format-check:
	mix format --check-formatted

lint:
	mix credo

test:
	mix test --trace --cover


