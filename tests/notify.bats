#!/usr/bin/env bats
# 
#+Bats tests for the notify module.
#+
#+Copyright (C) 2021  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	skipIfCI
	b_import "notify"
}

function testNotifyBasics {
	local cmd="$1"

	runSL $cmd -t 5000 "This is a blib test that should be visible."
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL "$cmd" --invalid "This should not be seen."
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	#we can't test much more without screenshot checks etc.
}

function testAbort {
	local ret=
	"$@"
	ret=$?
	[[ "$(b_getErrorHandler)" == "b_defaultErrorHandler" ]] || return 33
	echo "END"
	return $ret
}

function testNoErrorErrorHandler {
	b_setErrorHandler "b_notify_sendNoError --invalid"

	B_ERR="some error"
	B_E
}

@test "b_notify_send" {
	skipIfNoDbus

	testNotifyBasics "b_notify_send"

	runSL testAbort b_notify_send --invalid "This should not be seen."
	[ $status -ne 0 ]
	[ $status -ne 33 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" != *"END"* ]]
}

@test "b_notify_sendNoError" {
	skipIfNoDbus

	testNotifyBasics "b_notify_sendNoError"

	runSL testAbort b_notify_sendNoError --invalid "This should not be seen."
	[ $status -ne 0 ]
	[ $status -ne 33 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"END"* ]]

	#this should even work as error handler (if this hangs, there is a recursion bug)
	runSL testNoErrorErrorHandler
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
}

function skipIfNoDbus {
	hasDbus || skip "No dbus instance found. Skipping..."
}

function hasDbus {
	[ -e "/run/user/$EUID/bus" ] && return 0

	if [ $EUID -eq 0 ] ; then
	local path=
		for path in /run/user/*/bus ; do
			[[ "$path" != "/run/user/*/bus" ]] && return 0
		done
	fi

	return 1
}

@test "b_notify_waitForUserDbus" {
	hasDbus
	eStatus=$?
	local re='^/run/user/[0-9]+/bus$'

	runSL b_notify_waitForUserDbus "" 0
	[ $status -eq $eStatus ]
	[ $eStatus -eq 0 ] && [[ "$output" =~ $re ]] || [ -z "$output" ]

	if [ $eStatus -eq 0 ] ; then
		#this should not hang
		runSL b_notify_waitForUserDbus ""
		[ $status -eq 0 ]
		[[ "$output" =~ $re ]]
	fi

	runSL b_notify_waitForUserDbus "nonexisting"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
}
