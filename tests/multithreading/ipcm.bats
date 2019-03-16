#!/usr/bin/env bats
# 
#+Bats tests for the ipcm module.
#+
#+Copyright (C) 2019  David Hobach  LGPLv3
#+0.3

#load common test code
load ../test_common

T_IPCM_NS="ipcm-testing"
T_IPCM_KEY="ipc-test-counter"

function setup {
	loadBlib
	b_import "multithreading/ipcm"
	b_ipcm_setNamespace "$T_IPCM_NS"
}

function teardown {
	b_ipcm_unsetNamespace "$T_IPCM_NS"
}

@test "b_ipcm_getNamespace & b_ipcm_setNamespace" {
	testGetterSetter "b_ipcm_setNamespace" "foo bar"
}

#changeCounter [operator] [key] [current value]
function changeCounter {
	local operator="$1"
	local key="$2"
	local value="${3:-0}"
	local ret=

	[[ "$key" != "$T_IPCM_KEY" ]] && B_ERR="Unexpected key: $key" && B_E

	[ $operator -eq 0 ] && ret=$(( $value +1 )) || ret=$(( $value -1 ))

	#echo "$(date +%s%N) [$BASHPID] computed new value: $ret (old: $value)" >> /tmp/ipcm.log
	#we need to make this take a while to make racing conditions more likely
	sleep 0.1
	#echo "$(date +%s%N) [$BASHPID] setting new value: $ret (old: $value)" >> /tmp/ipcm.log

	echo "$ret"
	return 0
}

#changeTo [number] [ret value] [key] [current value]
function changeTo {
	echo "$1"
	return $2
}

function runTokenProcess {
	local plusOneTokens=10
	local minusOneTokens=9
	local out=

	while [ $plusOneTokens -gt 0 ] || [ $minusOneTokens -gt 0 ] ; do
		local choice=$(( $RANDOM % 2 ))
		local operator=

		if [ $choice -eq 0 ] ; then
			[ $plusOneTokens -le 0 ] && continue

			#+1
			operator=0
			plusOneTokens=$(( $plusOneTokens -1 ))
		else
			[ $minusOneTokens -le 0 ] && continue

			#-1
			operator=1
			minusOneTokens=$(( $minusOneTokens -1 ))
		fi
		
		out="$(b_ipcm_change "$T_IPCM_KEY" "changeCounter $operator")" || { B_ERR="The change function returned a non-zero exit code. Output: $out" ; B_E }
		[ -z "$out" ] && B_ERR="The change function didn't return the current value." && B_E
	done

	if [ $plusOneTokens -ne 0 ] || [ $minusOneTokens -ne 0 ] ; then
		B_ERR="Test programming error."
		B_E
	fi

	exit 0
}

@test "b_ipcm_change" {
	local testkey="b_ipcm_change-test"
	
	#failing
	runSL b_ipcm_change "$testkey" "changeTo 123 3"
	[ $status -eq $(( $B_RC +1 )) ]
	[ -z "$output" ]
	
	runSL b_ipcm_change "$testkey" "changeTo 123 3" 1
	[ $status -eq $(( $B_RC +1 )) ]
	[ -z "$output" ]

	runSL b_ipcm_change "$testkey" "nonexistingFunc"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#succeeding
	runSL b_ipcm_change "$testkey" "changeTo 666 0"
	[ $status -eq 0 ]
	[[ "$output" == "666" ]]

	runSL b_ipcm_get "$testkey"
	[ $status -eq 0 ]
	[[ "$output" == "666" ]]

	runSL b_ipcm_change "$testkey" "changeTo 777 0" 1
	[ $status -eq 0 ]
	[[ "$output" == "777" ]]

	runSL b_ipcm_get "$testkey"
	[ $status -eq 0 ]
	[[ "$output" == "777" ]]
}

@test "b_ipcm_change - concurrent processes" {
	#idea: 5+ processes, each owning ten +1 and nine -1 tokens. They may apply them in any order, but the operation takes some time (~100ms). In the end the result should still be the number of processes.
	local i=
	local pids=()

	for ((i=0;i<5;i++)) ; do
		runTokenProcess &
		pids+=($!)
	done

	local pid=
	for pid in "${pids[@]}" ; do
		wait "$pid" || { echo "[${pid}] exit code: $?" ; exit 1 ; }
	done

	echo "Checking the final result..."

	runSL b_ipcm_get "$T_IPCM_KEY"
	echo "expected: ${#pids[@]}"
	echo "found: $output"
	[ $status -eq 0 ]
	[ $output -eq ${#pids[@]} ]
}

@test "b_ipcm_get" {
	#it should almost never fail, even not for nonexisting namespaces
	#and we already did some tests above

	runSL b_ipcm_get "nonexistingkey"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_ipcm_get "nonexistingkey" "foo fallback"
	[ $status -eq 0 ]
	[[ "$output" == "foo fallback" ]]

	b_ipcm_setNamespace "nonexisting"

	runSL b_ipcm_get "$T_IPCM_KEY"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_ipcm_get "$T_IPCM_KEY" "fb"
	[ $status -eq 0 ]
	[[ "$output" == "fb" ]]

	#cleanup
	b_ipcm_setNamespace "$T_IPCM_NS"
}

@test "b_ipcm_unsetNamespace" {
	#make sure there's something to unset
	runSL b_ipcm_change "$T_IPCM_KEY" "changeTo 666 0"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "666" ]]

	runSL b_ipcm_get "$T_IPCM_KEY"
	echo "$output"
	[ $status -eq 0 ]
	[ -n "$output" ]

	runSL b_ipcm_unsetNamespace "$T_IPCM_NS"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_ipcm_get "$T_IPCM_KEY"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_ipcm_get "$T_IPCM_KEY" "fb"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "fb" ]]

	runSL b_ipcm_unsetNamespace "$T_IPCM_NS" 1
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_ipcm_get "$T_IPCM_KEY"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_ipcm_get "$T_IPCM_KEY" "fb"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "fb" ]]
}
