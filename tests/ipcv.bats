#!/usr/bin/env bats
# 
#+Bats tests for the ipcv module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "ipcv"
}

#writer thread  [use namespace function (default: 1/no)]
function testWriter1 {
	local useNsFunc="${2:-1}"

	for ((T_COUNTER=0; T_COUNTER<10; T_COUNTER++)) ; do
		T_DATE="$(date +%s)" || exit 1
		b_ipcv_save "blib-ipcv-testing" "T_DATE" "T_COUNTER" || exit 2
		echo "writer [${BASHPID}] T_DATE: $T_DATE"
		echo "writer [${BASHPID}] T_COUNTER & iter: $T_COUNTER"
		sleep 1
	done

	sleep 2

	if [ $useNsFunc -eq 0 ] ; then
		b_ipcv_unsetNamespace "blib-ipcv-testing" || exit 21
	else
		b_ipcv_unset "blib-ipcv-testing" "T_DATE" "T_COUNTER" || exit 22
	fi
}

#global vars for the below tests
#T_DATE=
#T_COUNTER=
#declare -A T_ARR

#reader thread [use namespace function (default: 1/no)]
function testReader1 {
	local useNsFunc="${1:-1}"
	local now=
	local diffDate=
	local diffCnt=
	local i=

	#test load
	for ((i=0; i<10; i++)) ; do
		now="$(date +%s)" || exit 77
		
		if [ $useNsFunc -eq 0 ] ; then
			b_ipcv_loadNamespace "blib-ipcv-testing" || exit 33
		else
			b_ipcv_loadNamespace "blib-ipcv-testing" "T_DATE" "T_COUNTER" || exit 34
		fi

		#test for correct return values
		diffDate=$(( $now - $T_DATE))
		diffCnt=$(( $T_COUNTER - $i ))
		echo "reader [${BASHPID}] iter: $i"
		echo "reader [${BASHPID}] T_DATE: $T_DATE"
		echo "reader [${BASHPID}] T_COUNTER: $T_COUNTER"
		echo "reader [${BASHPID}] diffDate: $diffDate"
		echo "reader [${BASHPID}] diffCnt: $diffCnt"
		[ -z "$T_DATE" ] && exit 1
		[ -z "$T_COUNTER" ] && exit 2
		[ $diffDate -gt 2 ] && exit 3
		[ $diffDate -lt 0 ] && exit 4
		[ $diffCnt -gt 2 ] && exit 5
		[ $diffCnt -lt -1 ] && exit 6

		sleep 1
	done

	sleep 4
	#test unset used by writer (we also need to unset the local variable here)
	unset T_DATE
	unset T_COUNTER
	if [ $useNsFunc -eq 0 ] ; then
		b_ipcv_loadNamespace "blib-ipcv-testing" || exit 35
	else
		b_ipcv_loadNamespace "blib-ipcv-testing" "T_DATE" "T_COUNTER" || exit 36
	fi
	declare -p "T_DATE" &> /dev/null && exit 11
	declare -p "T_COUNTER" &> /dev/null && exit 12

	return 0
}

#execWriterReaderTest [use namespace function (default: 1/no)]
function execWriterReaderTest {
	#idea: 1 writer, 3+ reader threads
	#the writer updates a shared variable with the current time and a counter every second for ~12s, the readers check for 10s whether the last update is at most 2s ago
	#after 14s they test whether the unset was successful
	
	local useNsFunc="${1:-1}"
	local pids=()

	testWriter1 "$useNsFunc" &
	pids+=($!)
	sleep 1
	testReader1 "$useNsFunc" &
	pids+=($!)
	testReader1 "$useNsFunc" &
	pids+=($!)
	testReader1 "$useNsFunc" &
	pids+=($!)
	testReader1 "$useNsFunc" &
	pids+=($!)

	local pid=
	local status=-1
	for pid in "${pids[@]}" ; do
		wait "$pid"
		status=$?
		[ $status -ne 0 ] && echo "[${pid}] exit code: $status" && exit 1
	done

	return 0
}

@test "b_ipcv_save" {
	#mostly tests for failing outcomes, successful ones can be found at 1 writer, multiple readers
	runB b_ipcv_save "invalid/ns" "T_DATE"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runB b_ipcv_save"/holymoly" "T_DATE"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runB b_ipcv_save "valid-ns" "T_DATEFOO"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#used in the tests below:
	T_DATE=1
	T_COUNTER="foo bar"
	declare -A T_ARR=( ["el"]="this is" ["el 2"]="a test" ["l foo"]="myfriend?!" )
	runB b_ipcv_save "test-ns" "T_DATE" "T_COUNTER" "T_ARR"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "b_ipcv_load & b_ipcv_loadNamespace" {
	#mostly tests for failing outcomes, successful ones can be found at 1 writer, multiple readers
	T_DATE=2
	T_COUNTER="asd"

	runB b_ipcv_load "invalid/ns/more" "T_DATE"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runB b_ipcv_load "invalid/ns/more" "T_DATE"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#existing namespace, non-existing var
	runB b_ipcv_load "test-ns" "T_foo"
	[ $status -eq 1 ]
	[ -z "$output" ]
	
	runB b_ipcv_load "test-ns" "T_foo" "T_foo2" "T_foo3"
	[ $status -eq 3 ]
	[ -z "$output" ]

	runB b_ipcv_load "test-ns" "T_foo" "T_DATE" "T_foo3" "T_ARR" "T_COUNTER"
	[ $status -eq 2 ]
	[ -z "$output" ]
	b_ipcv_load "test-ns" "T_foo" "T_DATE" "T_foo3" "T_ARR" "T_COUNTER" || [ $? -eq 2 ]
	echo "T_DATE: $T_DATE"
	echo "T_COUNTER: $T_COUNTER"
	[ $T_DATE -eq 1 ]
	[[ "$T_COUNTER" == "foo bar" ]]
	[ ${#T_ARR[@]} -eq 3 ]
	[[ "${T_ARR["el"]}" == "this is" ]]
	[[ "${T_ARR["el 2"]}" == "a test" ]]
	[[ "${T_ARR["l foo"]}" == "myfriend?!" ]]

	#loadNamespace
	runB b_ipcv_loadNamespace "/invalid"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#cleanup
	T_DATE=
	T_COUNTER=
}

@test "b_ipcv_unset & b_ipcv_unsetNamespace" {
	T_DATE="holy"
	T_COUNTER="moly"
	unset T_ARR

	b_ipcv_loadNamespace "test-ns"
	[ $T_DATE -eq 1 ]
	[[ "$T_COUNTER" == "foo bar" ]]

	runB b_ipcv_unset "test-ns" "T_COUNTER"
	[ $status -eq 0 ]
	[ -z "$output" ]

	T_DATE="holy"
	T_COUNTER="moly"

	b_ipcv_loadNamespace "test-ns"
	[ $T_DATE -eq 1 ]
	[[ "$T_COUNTER" == "moly" ]]
	runB declare -p "T_ARR"
	[ $status -eq 0 ]
	[ -n "$output" ]

	T_COUNTER=1
	runB b_ipcv_save "test-ns" "T_COUNTER" "T_DATE"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_ipcv_unsetNamespace "test-ns"
	[ $status -eq 0 ]
	[ -z "$output" ]

	T_DATE="holy"
	T_COUNTER="moly"
	unset T_ARR

	runB b_ipcv_loadNamespace "test-ns"
	[ $status -ne 0 ]
	[ -n "$output" ]
	b_setBE 1
	b_ipcv_loadNamespace "test-ns" || true
	b_resetErrorHandler
	[[ "$T_DATE" == "holy" ]]
	[[ "$T_COUNTER" == "moly" ]]
	runB declare -p "T_ARR"
	[ $status -ne 0 ]

	runB b_ipcv_load "test-ns" "T_DATE" "T_COUNTER" "T_ARR"
	[ $status -ne 0 ]
	[ -n "$output" ]
	b_setBE 1
	b_ipcv_load "test-ns" "T_DATE" "T_COUNTER" "T_ARR" || true
	b_resetErrorHandler
	[[ "$T_DATE" == "holy" ]]
	[[ "$T_COUNTER" == "moly" ]]
	runB declare -p "T_ARR"
	[ $status -ne 0 ]
}

@test "1 writer, multiple readers" {
	runB execWriterReaderTest 0
	echo "$output"
	[ $status -eq 0 ]

	runB execWriterReaderTest 1
	echo "$output"
	[ $status -eq 0 ]
}
