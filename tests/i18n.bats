#!/usr/bin/env bats
# 
#+Bats tests for the i18n module.
#+
#+Copyright (C) 2022  David Hobach  LGPLv3
#+0.2

#load common test code
load test_common

function setup {
	loadBlib
	b_import "i18n"
}

function setTimezone {
	local tz="$1"
	timedatectl set-timezone "$tz"
}

function testSetRandomTimezone {
	runSL b_execFuncAs "root" b_i18n_setRandomSystemTimezone "i18n" - - "$@"
}

@test "b_i18n_getSystemTimezone & b_i18n_setRandomSystemTimezone" {
	local re='^[A-Z][a-z]+[A-Za-z_/-]+$'

	runSL b_i18n_getSystemTimezone
	[ $status -eq 0 ]
	[[ "$output" =~ $re ]]
	local orig="$output"

	skipIfNotRoot

	testSetRandomTimezone "nonexisting"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"Country not found"* ]]

	testSetRandomTimezone
	[ $status -eq 0 ]
	[[ "$output" =~ $re ]]
	[[ "$output" != "$orig" ]] #may fail very rarely
	local last="$output"

	testSetRandomTimezone "" 3
	[ $status -eq 0 ]
	[[ "$output" =~ $re ]]
	[[ "$output" != "$orig" ]] #may fail very rarely
	[[ "$output" != "$last" ]] #may fail very rarely

	testSetRandomTimezone "DE"
	[ $status -eq 0 ]
	[[ "$output" == "Europe/Berlin" ]] || [[ "$output" == "Europe/Busingen" ]]

	testSetRandomTimezone "IN"
	[ $status -eq 0 ]
	[[ "$output" == "Asia/Kolkata" ]]

	runSL b_i18n_getSystemTimezone
	[ $status -eq 0 ]
	[[ "$output" == "Asia/Kolkata" ]]

	#set back to original
	runSC b_execFuncAs "root" setTimezone - - "$orig"
	[ $status -eq 0 ]
}
