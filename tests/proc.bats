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

#getProcFixture [name]
#[name]: name of the ini fixture to obtain
#returns: full path to the respective file
function getProcFixture {
	echo "${FIXTURES_DIR}/proc/${1}"
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

@test "b_proc_resolveSignal" {
	runSL b_proc_resolveSignal
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_proc_resolveSignal 10
	[ $status -eq 0 ]
	[[ "$output" == "10" ]]

	runSL b_proc_resolveSignal "SIGTERM"
	[ $status -eq 0 ]
	[[ "$output" == "15" ]]

	runSL b_proc_resolveSignal "USR1"
	[ $status -eq 0 ]
	[[ "$output" == "10" ]]
}

#testKillAndWait [func] [use pid = true(0)/false(1)]
function testKillAndWait {
	#NOTE: b_proc_killByRegexAndWait seems to be a _lot_ slower (greater diffs) than b_proc_killAndWait

	local func="${1:-"b_proc_killAndWait"}"
	local usePid="${2:-0}"
	local misbehaving_process="$(getProcFixture "misbehaving")"
	local proc="misbehaving"

	runSL "$func" 1 nonexisting 3
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"signal"* ]]

	#non-existing PID should be OK
	runSL "$func" "nonexisting"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#regular SIGTERM
	local startTime="$(date +%s%3N)"
	"$misbehaving_process" &
	[ $usePid -eq 0 ] && proc=$!
	runSL "$func" "$proc"
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	echo "$diff"
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ $diff -gt 0 ]
	[ $diff -lt 1500 ]

	#SIGKILL should also work
	local startTime="$(date +%s%3N)"
	"$misbehaving_process" &
	[ $usePid -eq 0 ] && proc=$!
	runSL "$func" "$proc" "SIGKILL"
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	echo "$diff"
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ $diff -gt 0 ]
	[ $diff -lt 1500 ]

	#test wait, if process takes time to finish
	local startTime="$(date +%s%3N)"
	"$misbehaving_process" 0 &
	[ $usePid -eq 0 ] && proc=$!
	runSL "$func" "$proc" ""
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	echo "$diff"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ $diff -gt 4000 ]
	[ $diff -lt 6000 ]

	#test timeout
	local startTime="$(date +%s%3N)"
	"$misbehaving_process" 0 &
	[ $usePid -eq 0 ] && proc=$!
	runSL "$func" "$proc" "" 1
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	echo "$diff"
	[ $status -ne 0 ]
	[ -z "$output" ]
	[ $diff -gt 800 ]
	[ $diff -lt 3000 ]
}

@test "b_proc_killAndWait" {
	testKillAndWait
}

@test "b_proc_killByRegexAndWait" {
	testKillAndWait "b_proc_killByRegexAndWait" 1
}
