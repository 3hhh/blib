#!/usr/bin/env bats
# 
#+This is not a real test, but can be used to execute some code *before* any bats tests are run.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.1

#load common test code
load test_common

function setup {
	clearBlibTestState 
}

@test "blib: pre test stub" {
	#empty
	[ 1 -eq 1 ]
}
