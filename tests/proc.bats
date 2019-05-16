#!/usr/bin/env bats
# 
#+Bats tests for the arr module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.2

#load common test code
load test_common

function setup {
	loadBlib
	b_import "proc"
}

@test "b_proc_pidExists" {
	runSL b_proc_pidExists 1
	[ -z "$output" ]
	[ $status -eq 0 ]

	runSL b_proc_pidExists "a"
	[ -z "$output" ]
	[ $status -ne 0 ]

	runSL b_proc_pidExists "$$"
	[ -z "$output" ]
	[ $status -eq 0 ]

	runSL b_proc_pidExists "$BASHPID"
	[ -z "$output" ]
	[ $status -eq 0 ]

	runSL b_proc_pidExists 0
	[ -z "$output" ]
	[ $status -ne 0 ]
}

function testProcess {
	sleep 1
}

function childTest {
	testProcess &
	local pid="$!"
	b_proc_childExists "$pid" || exit 1
	sleep 0.1
	b_proc_childExists "$pid" || exit 2

	wait "$pid"
	b_proc_childExists "$pid" && exit 3
	exit 0
}

@test "b_proc_childExists" {
	runSL b_proc_childExists "$$"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL childTest
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "b_proc_waitForPid" {
	local startTime="$(date +%s%3N)"
	runSL b_proc_waitForPid 1 1
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ $diff -lt 1500 ]
	[ $diff -gt 500 ]

	local startTime="$(date +%s%3N)"
	testProcess &
	runSL b_proc_waitForPid $! 1
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ $diff -lt 1500 ]
	[ $diff -gt 500 ]

	#non existing pid
	runSL b_proc_waitForPid 999999999999
	[ $status -eq 0 ]
	[ -z "$output" ]
}
