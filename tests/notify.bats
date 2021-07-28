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
	testNotifyBasics "b_notify_send"

	runSL testAbort b_notify_send --invalid "This should not be seen."
	[ $status -ne 0 ]
	[ $status -ne 33 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" != *"END"* ]]
}

@test "b_notify_sendNoError" {
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
