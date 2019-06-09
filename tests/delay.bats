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

	echo 1
	local cmd=
	printf -v cmd 'echo $SECONDS >> %q' "$tfile"
	b_delay_to $(( $pre +1 )) "$cmd"
	b_delay_to $(( $pre +2 )) "$cmd"

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
	[[ "$out" == $(( $pre +1 ))$'\n'$(( $pre +2 )) ]]

	rm -f "$tfile"
}
