#!/usr/bin/env bats
# 
#+Bats tests for the cdoc module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "traps"
}

@test "b_traps_getCodeFor" {
	runB b_traps_getCodeFor "SIGTERM"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_traps_getCodeFor "SIGINT"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_traps_getCodeFor "SIGFOO"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runB b_traps_getCodeFor "EXIT"
	[ $status -eq 0 ]
	[[ "$output" == "bats_teardown_trap" ]]
}

function trapAddRemove {
	local out=""
	b_traps_add 'echo "foo bar"' SIGTERM || exit 1
	
	b_traps_add 'echo "it is me"; echo "yes"' SIGTERM test1 || exit 1

	b_traps_add 'echo "from l3"' SIGTERM l3 || exit 1

	local ref='echo "foo bar"
#begin: test1
echo "it is me"; echo "yes"
#end: test1
#begin: l3
echo "from l3"
#end: l3'

	local cur=""
	cur="$(b_traps_getCodeFor SIGTERM)" || exit 1
	if [[ "$cur" != "$ref" ]] && [[ "$cur" != "$ref"$'\n' ]] ; then
		echo "Invalid trap set:"
		echo "$cur"
		exit 1
	fi

	b_traps_add 'echo anonymous' SIGTERM || exit 1
	b_traps_add 'echo "and another"' SIGTERM another || exit 1

	#NOTE: the remove must not happen in a subshell, but in the same shell that the add happened
	b_traps_remove SIGTERM "another" || exit 1
	b_traps_remove SIGTERM "test1" || exit 1

	local ref='echo "foo bar"
#begin: l3
echo "from l3"
#end: l3
echo anonymous'

	cur="$(b_traps_getCodeFor SIGTERM)" || exit 1
	if [[ "$cur" != "$ref" ]] && [[ "$cur" != "$ref"$'\n' ]] ; then
		echo "Invalid trap 2 set:"
		echo "$cur"
		exit 1
	fi

	#trigger SIGTERM trap
	kill $BASHPID
	sleep 0.01
}

@test "b_traps_add & b_traps_remove (valid)" {
	#since bats already uses EXIT, we stick to SIGTERM
	local out=""
	runB trapAddRemove
	echo "stat: $status"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "foo bar"$'\n'"from l3"$'\n'"anonymous" ]]
}

@test "b_traps_add (invalid)" {
	runB b_traps_add "echo foo" SIGFOO "tag"
	[ -n "$output" ]
	[ $status -ne 0 ]

	runB b_traps_add "echo foo" SIGASD
	[ -n "$output" ]
	[ $status -ne 0 ]
}

@test "b_traps_remove (invalid)" {
	runB b_traps_remove SIGFOO "tag"
	[ -n "$output" ]
	[ $status -ne 0 ]

	runB b_traps_remove SIGFOO
	[ -n "$output" ]
	[ $status -ne 0 ]

	runB b_traps_remove SIGINT
	[ -n "$output" ]
	[ $status -ne 0 ]

	b_traps_add "echo anonymous" SIGINT
	[ $? -eq 0 ]

	b_traps_add "echo tag" SIGINT "tag"
	[ $? -eq 0 ]

	runB b_traps_remove SIGINT
	[ -n "$output" ]
	[ $status -ne 0 ]

	runB b_traps_remove SIGINT "tag2"
	[ -n "$output" ]
	[ $status -ne 0 ]

	runB b_traps_remove SIGINT "tag2"
	[ -n "$output" ]
	[ $status -ne 0 ]

	runB b_traps_remove SIGINT "tag"
	[ -z "$output" ]
	[ $status -eq 0 ]

	b_traps_remove SIGINT "tag"
	[ $? -eq 0 ]
}
