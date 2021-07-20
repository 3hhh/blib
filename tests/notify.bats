#!/usr/bin/env bats
# 
#+Bats tests for the notify module.
#+
#+Copyright (C) 2021  David Hobach  LGPLv3
#+0.2

#load common test code
load test_common

function setup {
	loadBlib
	b_import "notify"
}

@test "b_notify_send" {
	runSL b_notify_send "This is a blib test that should be visible."
	[ $status -eq 0 ]
	[ -z "$output" ]

	#we can't test much more without screenshot checks etc.
}
