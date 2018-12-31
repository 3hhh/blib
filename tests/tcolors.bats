#!/usr/bin/env bats
# 
#+Bats tests for the tcolors module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "tcolors"
}

@test "B_TCOLORS" {
	[ -n "${B_TCOLORS[green]}" ]
	[ -n "${B_TCOLORS[red]}" ]
}

@test "b_tcolors_getDeps" {
	runB b_tcolors_getDeps
	[ $status -eq 0 ]
	[ -n "$output" ]
}
