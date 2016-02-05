
all: escriptize

escriptize: get-deps compile xref
	./rebar escriptize

get-deps:
	@./rebar get-deps

compile: get-deps
	@./rebar compile

xref:
	./rebar xref skip_deps=true

clean:
	@./rebar clean
