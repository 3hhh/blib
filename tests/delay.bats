#!/usr/bin/env bats
# 
#+Bats tests for the date module.
#+
#+Copyright (C) 2019  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "delay"
}

@test "b_delay_to & b_delay_execute" {
	local tfile="$(mktemp)"
	[ -f "$tfile" ]
	local pre=$SECONDS
	local p1=$(( $pre +1 ))
	local p2=$(( $pre +2 ))

	echo 1
	local cmd=
	printf -v cmd 'echo -n $SECONDS >> %q' "$tfile"

	runSL b_delay_getCommandAt "$p1"
	[ $status -eq 0 ]
	[ -z "$output" ]

	b_delay_to "$p1" "$cmd"
	b_delay_to "$p2" "$cmd"

	runSL b_delay_getCommandAt "$p1"
	[ $status -eq 0 ]
	[[ "$output" == "$cmd" ]]

	runSL b_delay_getCommandAt "$p2"
	[ $status -eq 0 ]
	[[ "$output" == "$cmd" ]]

	b_delay_to "$p1" "$cmd"

	echo 2
	local cnt=0
	local ret=
	while [ $cnt -ne 2 ] ; do
		set +e
		b_delay_execute "$SECONDS"
		ret=$?
		set -e
		[ $ret -eq 0 ]
		cnt=$(( $cnt + $B_DELAY_EXECUTED))
		sleep 0.1
	done

	echo 3
	[ -f "$tfile" ]
	local out="$(cat "$tfile")"
	echo "FILE:"
	echo "$out"
	[[ "$out" == "$p1$p1$p2" ]]

	echo 4
	runSL b_delay_getCommandAt "$p1"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_delay_getCommandAt "$p2"
	[ $status -eq 0 ]
	[ -z "$output" ]

	rm -f "$tfile"
}
