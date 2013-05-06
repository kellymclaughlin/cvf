.PHONY: all get-deps clean compile run eunit check check-eunit doc

REBAR=$(shell which rebar || echo ./rebar)

all: get-deps compile

get-deps:
	@$(REBAR) get-deps

clean:
	@$(REBAR) clean

compile:
	@$(REBAR) compile

eunit: compile
	@$(REBAR) eunit skip_deps=true

check: compile
	dialyzer --verbose --no_check_plt --no_native --fullpath \
		$(CHECK_FILES) \
		-Wunmatched_returns \
		-Werror_handling

check-eunit: eunit
	dialyzer --verbose --no_check_plt --no_native --fullpath \
		$(CHECK_EUNIT_FILES) \
		-Wunmatched_returns \
		-Werror_handling

doc:
	@$(REBAR) doc skip_deps=true
