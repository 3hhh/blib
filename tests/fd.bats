#!/usr/bin/env bats
# 
#+Bats tests for the fd module.
#+
#+Copyright (C) 2021  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "fd"
}

function isIntegerList {
	b_import "types"

	local list="$1"
	local line=
	while IFS= read -r line ; do
		b_types_assertInteger "$line"
	done <<< "$list"
}

@test "b_fd_getOpen" {
	runSL b_fd_getOpen "foobar"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_fd_getOpen
	[ $status -eq 0 ]
	[ -n "$output" ]
	isIntegerList "$output"

	runSL b_fd_getOpen "$$"
	[ $status -eq 0 ]
	[ -n "$output" ]
	isIntegerList "$output"
}

@test "b_fd_closeNonStandard" {
	( b_fd_closeNonStandard
	sleep 3
	) &
	disown

	runSL b_fd_getOpen "$!"
	[ $status -eq 0 ]
	echo "$output"
	local line=
	while IFS= read -r line ; do
		[ $line -le 2 ]
	done <<< "$output"
}

@test "b_fd_closeAll" {
	( b_fd_closeAll
	sleep 3
	) &
	disown

	runSL b_fd_getOpen "$!"
	[ $status -eq 0 ]
	echo "$output"
	[ -z "$output" ]
}
