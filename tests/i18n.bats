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

@test "b_i18n_getSystemTimezone & b_i18n_setRandomSystemTimezone" {
	local re='^[A-Z][a-z]+[A-Za-z_/]+$'

	runSL b_i18n_getSystemTimezone
	[ $status -eq 0 ]
	[[ "$output" =~ $re ]]
	local orig="$output"

	runSL b_i18n_setRandomSystemTimezone "nonexisting"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"Country not found"* ]]

	runSL b_i18n_setRandomSystemTimezone
	[ $status -eq 0 ]
	[[ "$output" =~ $re ]]
	[[ "$output" != "$orig" ]] #may fail very rarely
	local last="$output"

	runSL b_i18n_setRandomSystemTimezone "" 3
	[ $status -eq 0 ]
	[[ "$output" =~ $re ]]
	[[ "$output" != "$orig" ]] #may fail very rarely
	[[ "$output" != "$last" ]] #may fail very rarely

	runSL b_i18n_setRandomSystemTimezone "DE"
	[ $status -eq 0 ]
	[[ "$output" == "Europe/Berlin" ]] || [[ "$output" == "Europe/Busingen" ]]

	runSL b_i18n_setRandomSystemTimezone "IN"
	[ $status -eq 0 ]
	[[ "$output" == "Asia/Kolkata" ]]

	runSL b_i18n_getSystemTimezone
	[ $status -eq 0 ]
	[[ "$output" == "Asia/Kolkata" ]]

	#set back to original
	run timedatectl set-timezone "$orig"
	[ $status -eq 0 ]
}
