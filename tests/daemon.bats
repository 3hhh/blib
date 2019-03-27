#!/usr/bin/env bats
# 
#+Bats tests for the daemon module.
#+
#+Copyright (C) 2019  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

#id of the daemon used for testing
T_DAEMON="blib-testdaemon"

function setup {
	loadBlib
	b_import "daemon"

	#cleanup from previous tests
	rm -rf "${BLIB_STORE["BLIB_DAEMON_MTX_DIR"]}/$T_DAEMON"
}

#daemon_main [loop flag] "test"
function daemon_main {
	local loopFlag="$1"
	local msg="$2"

	[[ "$loopFlag" != "0" ]] && [[ "$loopFlag" != "1" ]] && B_ERR="Parameter passing failed." && B_E
	[[ "$msg" != "test" ]] && B_ERR="Failed to get the second parameter." && B_E

	[[ "$B_DAEMON_ID" != "$T_DAEMON" ]] && B_ERR="Couldn't find the correct daemon ID." && B_E

	#test stdin (shouldn't hang)
	cat -

	echo "stdout here"
	>&2 echo "stderr here"

	#NOTE: bats will wait for the sleep to end unless the process is killed (either as part of a single run or as part of the entire test) --> we must not make it too long
	#cf. https://github.com/bats-core/bats-core/issues/205
	[ $loopFlag -eq 0 ] && sleep 10
}

#testInvalidId [id]
function testInvalidId {
	local id="$1"
	local msg="test"

	runSL b_daemon_start "$id" 1 "$msg"
	[ $status -ne 0 ]
	[[ "$output" == *"doesn't match"* ]]

	runSL b_daemon_status "$id"
	[ $status -ne 0 ]
	[[ "$output" == *"doesn't match"* ]]

	runSL b_daemon_getPid "$id"
	[ $status -ne 0 ]
	[[ "$output" == *"doesn't match"* ]]
}

@test "invalid IDs" {
	testInvalidId "this/is/an/invalid/id"
	testInvalidId "stränge s!gns"
}

#postDaemonStartChecks [id] [stdout file] [stderr file] [quiet flag]
function postDaemonStartChecks {
	local did="$1"
	local outFile="$2"
	local out=
	[ -n "$outFile" ] && out="$(< "$outFile")"
	local errFile="$3"
	local err=
	[ -n "$errFile" ] && err="$(< "$errFile")"
	local quiet="$4"

	[ -z "$B_DAEMON_ID" ]

	runSL b_daemon_getPid "$did"
	[ $status -eq 0 ]
	[ -n "$output" ]

	runSL b_daemon_statusPid "$did"
	[ $status -eq 0 ]
	[ -n "$output" ]

	runSL b_daemon_status "$did"
	[ $status -eq 0 ]
	if [ $quiet -eq 0 ] ; then
		[ -z "$output" ]
	else
		[ -n "$output" ]
	fi

	#wait for the daemon to do its printing
	sleep 0.2

	#check
	if [ -n "$outFile" ] ; then
		echo "stdout check"
		[[ "$out" == *"stdout here"* ]]
		[[ "$out" != *"ERROR"* ]]
	fi

	if [ -n "$errFile" ] ; then
		echo "stderr check"
		[[ "$err" == *"stderr here"* ]]
		[[ "$err" != *"ERROR"* ]]
	fi
}

#postDaemonStopChecks [id] [quiet flag]
function postDaemonStopChecks {
	local did="$1"
	local quiet="$2"

	[ -z "$B_DAEMON_ID" ]

	runSL b_daemon_getPid "$did"
	echo "$output"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_daemon_statusPid "$did"
	echo "$output"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_daemon_status "$did"
	echo "$output"
	[ $status -ne 0 ]
	if [ $quiet -eq 0 ] ; then
		[ -z "$output" ]
	else
		[ -n "$output" ]
	fi

	#ensure the mutex is gone
	echo "mutex check"
	[ ! -e "/tmp/blib_daemon/$did" ]
}

#basicDaemonTests [quiet flag] [stdout file] [stderr file]
function basicDaemonTests {
	local quietPass="$1"
	local quiet="${1:-0}"
	local out="$2"
	local err="$3"
	local did="$T_DAEMON"
	local msg="test"
	echo "daemon stdout: $out"
	echo "daemon stderr: $err"

	runSC b_daemon_init "$quietPass" "" "$out" "$err"
	[ $status -eq 0 ]
	[ -z "$output" ]

	b_daemon_init "$quietPass" "" "$out" "$err"
	[ $? -eq 0 ]
	
	echo "A"
	postDaemonStopChecks "$did" "$quiet"

	#NOTE: the entire test will still wait for the daemon to finish
	#cf. https://github.com/bats-core/bats-core/issues/205
	runSL b_daemon_start "$did" 0 "$msg"
	if [ $quiet -eq 0 ] ; then
		[ -z "$output" ] ;
	else
		[[ "$output" == *"started"* ]]
	fi

	postDaemonStartChecks "$did" "$out" "$err" "$quiet"

	echo "B"
	runSL b_daemon_start "$did" 0 "$msg"
	[ $status -ne 0 ]
	[ -n "$output" ]
	[[ "$output" == *"running already"* ]]

	postDaemonStartChecks "$did" "$out" "$err" "$quiet"

	runSL b_daemon_stop "$did"
	[ $status -eq 0 ]
	if [ $quiet -eq 0 ] ; then
		[ -z "$output" ] ;
	else
		[[ "$output" == *"stopped"* ]]
	fi

	echo "C"
	postDaemonStopChecks "$did" "$quiet"

	runSL b_daemon_stop "$did"
	[ $status -eq 3 ]
	if [ $quiet -eq 0 ] ; then
		[ -z "$output" ] ;
	else
		[[ "$output" == *"wasn't running"* ]]
	fi

	postDaemonStopChecks "$did" "$quiet"

	echo "D"
	runSL b_daemon_start "$did" 0 "$msg"
	[ $status -eq 0 ]
	if [ $quiet -eq 0 ] ; then
		[ -z "$output" ] ;
	else
		[[ "$output" == *"started"* ]]
	fi

	runSL b_daemon_restart "$did" "" 0 "$msg"
	[ $status -eq 0 ]
	if [ $quiet -eq 0 ] ; then
		[ -z "$output" ] ;
	else
		[[ "$output" == *"restarted"* ]]
	fi

	echo "E"
	postDaemonStartChecks "$did" "$out" "$err" "$quiet"

	runSL b_daemon_stop "$did"
	[ $status -eq 0 ]
	if [ $quiet -eq 0 ] ; then
		[ -z "$output" ] ;
	else
		[[ "$output" == *"stopped"* ]]
	fi

	postDaemonStopChecks "$did" "$quiet"
	echo "F"
}

@test "basic daemon functionality" {
	local out="$(mktemp)"
	local err="$(mktemp)"

	basicDaemonTests "" "$out" "$err"
	basicDaemonTests 0 "$out" "$err"
	basicDaemonTests 1 "$out" "$err"
	basicDaemonTests

	#cleanup
	rm -f "$out" "$err"
}

function daemon_main2 {
	#ignore kill requests
	trap -- '' SIGINT SIGTERM

	sleep 10
}

@test "b_daemon_stop with kill" {
	b_daemon_init "" "daemon_main2"
	[ $? -eq 0 ]
	
	#ensure it is down
	runSL b_daemon_status "$T_DAEMON"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_daemon_start "$T_DAEMON"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_daemon_status "$T_DAEMON"
	[ $status -eq 0 ]
	[ -z "$output" ]
	
	runSL b_daemon_stop "$T_DAEMON" 1
	[ $status -eq 2 ]
	[ -z "$output" ]

	runSL b_daemon_status "$T_DAEMON"
	[ $status -ne 0 ]
	[ -z "$output" ]
}
