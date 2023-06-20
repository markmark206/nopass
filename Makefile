.PHONY: test

lint:
	mix credo

test:
	mix test --trace --cover
