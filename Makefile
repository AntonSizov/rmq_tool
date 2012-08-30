all: generate

get-deps:
	@./rebar get-deps

clean:
	@./rebar clean

compile: get-deps
	@./rebar compile

generate: compile
	@rm -rf ./rel/rmq_tool
	@./rebar generate

console:
	./rel/rmq_tool/bin/rmq_tool console

