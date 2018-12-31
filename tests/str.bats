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
	runB b_str_stripQuotes "foobar moep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar moep" ]]

	runB b_str_stripQuotes "foobar' moep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar' moep" ]]

	runB b_str_stripQuotes "foobar' m'oep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar' m'oep" ]]

	runB b_str_stripQuotes 'f"oobar m'"'"'oep"'
	[ $status -eq 0 ]
	[[ "$output" == 'f"oobar m'"'"'oep"' ]]

	runB b_str_stripQuotes '"foobar moep"'
	[ $status -eq 0 ]
	[[ "$output" == 'foobar moep' ]]

	runB b_str_stripQuotes "'foobar moep'"
	[ $status -eq 0 ]
	[[ "$output" == 'foobar moep' ]]

	runB b_str_stripQuotes '"foobar moep'"'"
	[ $status -eq 0 ]
	[[ "$output" == '"foobar moep'"'" ]]

	runB b_str_stripQuotes "'"'"foobar moep"'
	[ $status -eq 0 ]
	[[ "$output" == "'"'"foobar moep"' ]]
}

@test "b_str_trim" {
	runB b_str_trim "foobar moep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar moep" ]]

	runB b_str_trim "	foobar	moep"
	[ $status -eq 0 ]
	[[ "$output" == "foobar	moep" ]]

	runB b_str_trim "foobar  moep "
	[ $status -eq 0 ]
	[[ "$output" == "foobar  moep" ]]

	runB b_str_trim "  	foobar  moep	   "
	[ $status -eq 0 ]
	[[ "$output" == "foobar  moep" ]]

	runB b_str_trim " 		foobar   moep				     "
	[ $status -eq 0 ]
	[[ "$output" == "foobar   moep" ]]
}
