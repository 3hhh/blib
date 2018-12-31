#!/usr/bin/env bats
# 
#+Bats tests for the arr module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.1

#load common test code
load test_common

function setup {
	loadBlib
	b_import "proc"
}

@test "b_proc_pidExists" {
	runB b_proc_pidExists 1
	[ -z "$output" ]
	[ $status -eq 0 ]

	runB b_proc_pidExists "a"
	[ -z "$output" ]
	[ $status -ne 0 ]

	runB b_proc_pidExists "$$"
	[ -z "$output" ]
	[ $status -eq 0 ]

	runB b_proc_pidExists "$BASHPID"
	[ -z "$output" ]
	[ $status -eq 0 ]

	runB b_proc_pidExists 0
	[ -z "$output" ]
	[ $status -ne 0 ]
}

function testProcess {
	sleep 1
}

@test "b_proc_waitForPid" {
	local startTime="$(date +%s%3N)"
	runB b_proc_waitForPid 1 1
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ $diff -lt 1500 ]
	[ $diff -gt 500 ]

	local startTime="$(date +%s%3N)"
	testProcess &
	runB b_proc_waitForPid $! 1
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ $diff -lt 1500 ]
	[ $diff -gt 500 ]

	#non existing pid
	runB b_proc_waitForPid 999999999999
	[ $status -eq 0 ]
	[ -z "$output" ]
}
