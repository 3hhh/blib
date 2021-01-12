#!/usr/bin/env bats
# 
#+Bats tests for the str module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "str"
}

@test "b_str_stripQuotes" {
	runSL b_str_stripQuotes "foobar moep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar moep" ]]

	runSL b_str_stripQuotes "foobar' moep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar' moep" ]]

	runSL b_str_stripQuotes "foobar' m'oep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar' m'oep" ]]

	runSL b_str_stripQuotes 'f"oobar m'"'"'oep"'
	[ $status -eq 0 ]
	[[ "$output" == 'f"oobar m'"'"'oep"' ]]

	runSL b_str_stripQuotes '"foobar moep"'
	[ $status -eq 0 ]
	[[ "$output" == 'foobar moep' ]]

	runSL b_str_stripQuotes "'foobar moep'"
	[ $status -eq 0 ]
	[[ "$output" == 'foobar moep' ]]

	runSL b_str_stripQuotes '"foobar moep'"'"
	[ $status -eq 0 ]
	[[ "$output" == '"foobar moep'"'" ]]

	runSL b_str_stripQuotes "'"'"foobar moep"'
	[ $status -eq 0 ]
	[[ "$output" == "'"'"foobar moep"' ]]
}

@test "b_str_trim" {
	runSL b_str_trim "foobar moep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar moep" ]]

	runSL b_str_trim "	foobar	moep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar	moep" ]]

	runSL b_str_trim "foobar  moep "
	[ $status -eq 0 ]
	[[ "$output" == "foobar  moep" ]]

	runSL b_str_trim "  	foobar  moep	   "
	[ $status -eq 0 ]
	[[ "$output" == "foobar  moep" ]]

	runSL b_str_trim " 		foobar   moep				     "
	[ $status -eq 0 ]
	[[ "$output" == "foobar   moep" ]]
}

@test "b_str_prefixLines" {
	runSL b_str_prefixLines "hello world!"
	[ $status -eq 0 ]
	[[ "$output" == "hello world!" ]]

	runSL b_str_prefixLines "hello"$'\n'"world!"
	[ $status -eq 0 ]
	[[ "$output" == "hello"$'\n'"world!" ]]

	runSL b_str_prefixLines "hello"$'\n'"world!" "foo"
	[ $status -eq 0 ]
	[[ "$output" == "foohello"$'\n'"fooworld!" ]]

	runSL b_str_prefixLines "hello" "foo"
	[ $status -eq 0 ]
	[[ "$output" == "foohello" ]]

	runSL b_str_prefixLines "" "foo"
	[ $status -eq 0 ]
	[[ "$output" == "foo" ]]
}
