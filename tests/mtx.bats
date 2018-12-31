#!/usr/bin/env bats
# 
#+Bats tests for the arr module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "mtx"
}

#runSingleMutexTest [mutex] [cleanup]
#[cleanup]: if set to 0 (default), remove the mutex in the end (and test that as well)
function runSingleMutexTest {
	local mutex="$1"
	local cleanup="${2:-0}"
	local t1Ret=""

	[ ! -e "$mutex" ]

	#1st try should obtain the mutex
	echo "1.1"
	runB b_mtx_try "$mutex"
	[ -d "$mutex" ]
	[ $status -eq 0 ]
	[ -n "$output" ]
	t1Ret="$output"

	#2nd try with the same block Id should work (we have the mutex already)
	echo "1.2"
	runB b_mtx_try "$mutex"
	[ -d "$mutex" ]
	[ $status -eq 0 ]
	[[ "$output" == "$t1Ret" ]]

	#different block ID/process ID should fail
	echo "2"
	runB b_mtx_try "$mutex" 1
	[ $status -eq 1 ]
	[ -n "$output" ]
	[ -d "$mutex" ]

	#further tries that should fail with varying params
	echo "3"
	runB b_mtx_try "$mutex" "foo"
	[ $status -eq 1 ]
	[ -n "$output" ]
	[ -d "$mutex" ]
	echo "4"
	runB b_mtx_try "$mutex" 666 1
	[ $status -eq 1 ]
	[ -n "$output" ]
	[ -d "$mutex" ]
	echo "5"
	runB b_mtx_try "$mutex" "$PPID"
	[ $status -eq 1 ]
	[ -n "$output" ]
	[ -d "$mutex" ]

	#totally invalid
	echo "6"
	runB b_mtx_try "/tmp"
	[ $status -ne 0 ]
	[ $status -ne 1 ]
	[ -n "$output" ]
	[ -d "$mutex" ]
	echo "7"
	runB b_mtx_try "/tmp" "888888"
	[ $status -ne 0 ]
	[ $status -ne 1 ]
	[ -n "$output" ]
	[ -d "$mutex" ]
	echo "8"
	runB b_mtx_try "/tmp" "" 1
	[ $status -ne 0 ]
	[ $status -ne 1 ]
	[ -n "$output" ]
	[ -d "$mutex" ]
	echo "9"
	runB b_mtx_try "/tmp" "1"
	[ $status -ne 0 ]
	[ $status -ne 1 ]
	[ -n "$output" ]
	[ -d "$mutex" ]
	echo "10"
	runB b_mtx_try "/tmp" "$$"
	[ $status -ne 0 ]
	[ $status -ne 1 ]
	[ -n "$output" ]
	[ -d "$mutex" ]
	echo "11"

	#temp release
	runB b_mtx_forceRelease "$mutex"
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ ! -e $mutex ]
	echo "12"

	#test stale mutex with imaginary block ID/pid
	runB b_mtx_try "$mutex" 9999999
	[ -d "$mutex" ]
	[ $status -eq 0 ]
	[[ "$output" == "b_mtx_release"* ]]
	echo "13"

	#it should fail without "claim stale"
	runB b_mtx_try "$mutex" "" 1
	[ -d "$mutex" ]
	[ $status -ne 0 ]
	[ -n "$output" ]
	[[ "$output" != "b_mtx"* ]]
	echo "14"

	#now the mutex is "stale" as there's no such pid, i.e. we should be able to obtain it with our block ID/pid:
	runB b_mtx_try "$mutex" "" 0
	[ -d "$mutex" ]
	[ $status -eq 0 ]
	[ -n "$output" ]
	echo "15"
	
	#cleanup: test the callback function (b_mtx_release)
	if [ $cleanup -eq 0 ] ; then
		#test the trap callback
		runB eval "$t1Ret"
		[ $status -eq 0 ]
		[ -z "$output" ]
		[ ! -e "$mutex" ]
	fi
	echo "16"

	return 0
}

@test "b_mtx_create" {
	runB b_mtx_create
	[ $status -eq 0 ]
	[[ "$output" == "/tmp/"* ]]
	[ ! -e "$output" ]

	local base="$(mktemp -d)"
	local base2="$base/ some spaces"

	runB b_mtx_create "$base2"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "$base2/"* ]]
	[ ! -e "$output" ]

	#cleanup
	[ -d "$base" ] && rm -rf "$base"
}

@test "b_mtx_try" {
	#we only check single threaded basic functionality here - concurrent mutex accesses should be checked by b_mtx_waitFor which calls this function
	local m1=""
	local m2=""

	m1="$(b_mtx_create)"
	[ ! -e "$m1" ]
	runSingleMutexTest "$m1"
	runSingleMutexTest "$m1"
	runSingleMutexTest "$m1" 1
	[ -d "$m1" ]
	m2="$(b_mtx_create)"
	[ ! -e "$m2" ]
	runSingleMutexTest "$m2"

	#cleanup
	rm -rf "$m1"
}

#fileWriter [file] [string] [mutex] [claim stale] [maximum time]
function fileWriter {
	local file="$1"
	shift
	local str="$1"
	shift
	local mutex="$1"
	shift
	#NOTE: we're running in a subshell, i.e. we need to use $BASHPID
	local blockId="$BASHPID"

	echo "block pid: $blockId"
	#echo "$mutex $blockId Started." >> /tmp/mtx.log

	#get mutex
	runB b_mtx_waitFor "$mutex" "$blockId" "$@"
	#echo "$mutex $blockId wait passed. status: $status output $output" >> /tmp/mtx.log
	echo "$blockId WAIT OUTPUT: $output WAIT END"
	echo "$blockId WAIT STATUS: $status"
	[ $status -eq 0 ]
	[[ "$output" == "b_mtx_release "* ]]
	echo "$blockId fw1"
	[ -d "$mutex" ]
	local relOut="$output"

	#write
	echo "$str" >> "$file"
	[ $? -eq 0 ]
	#echo "$mutex $blockId succ Wrote str." >> /tmp/mtx.log

	#release mutex
	echo "$blockId fw2"
	runB eval "$relOut"
	#echo "$mutex $blockId Released" >> /tmp/mtx.log
	[ $status -eq 0 ]
	echo "$blockId fw3"
	[ -z "$output" ]
	echo "$blockId fw4"
	#NOTE: the mutex may exist again as another process re-created it by now
	#[ ! -e "$mutex" ]
	#echo "fw5"
}

#runFileWriterSwarm [# threads] [file] [string] [mutex] [claim stale] [maximum time]
function runFileWriterSwarm {
	local x=$1
	shift
	local pids=""
	#create x threads
	for ((i=0; i < $x; i++)); do
		fileWriter "$@" &
		pids="$pids $!"
	done

	#wait for them to finish
	wait $pids
}

#assertOutFileOk [file] [#lines] [string]
#[#lines]: expected number of lines to be found in the given file
#[string]: each line must equal that string in order to pass the test
function assertOutFileOk {
	local file="$1"
	local expLines="$2"
	local str="$3"
	local i=0
	local line=""
	while IFS= read -r line ; do
		i=$(( i+1 ))
		[[ "$line" == "$str" ]]
	done < "$file"

	[ $i -eq $expLines ]
}

@test "b_mtx_waitFor - timeout" {
	local mtx="$(b_mtx_create)"

	#test timeout incl. time measurements
	#get the mutex
	runB b_mtx_waitFor "$mtx"
	[ $status -eq 0 ]
	echo 1
	[[ "$output" == "b_mtx_release "* ]]
	[ -d "$mtx" ]
	echo 2
	#try to get it again with a timeout, this time as pid=1
	local startTime="$(date +%s%3N)"
	runB b_mtx_waitFor "$mtx" 1 0 1000
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	echo 3
	[ $status -eq 1 ]
	[[ "$output" != "b_mtx_release "* ]]
	[ -d "$mtx" ]
	echo "diff: $diff"
	[ $diff -lt 2000 ]
	[ $diff -gt 500 ]

	local startTime="$(date +%s%3N)"
	runB b_mtx_waitFor "$mtx" 1 0 500
	local endTime="$(date +%s%3N)"
	local diff=$(( $endTime - $startTime ))
	[ $status -eq 1 ]
	[[ "$output" != "b_mtx_release "* ]]
	[ -d "$mtx" ]
	echo "diff: $diff"
	[ $diff -lt 1000 ]
	[ $diff -gt 100 ]

	#cleanup
	runB b_mtx_release "$mtx"
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ ! -e "$mtx" ]
}

@test "b_mtx_waitFor" {
	#basic idea:
	# create X processes protected by a mutex writing a common line l to a single file simultaneously
	#  if it works correctly: the file has X identical lines = l
	#  if it fails: the file has garbled lines != l

	local out="$(mktemp)"
	echo "OUT FILE: $out"
	local mtx="$(b_mtx_create)"
	local line="this is a test line my friends?!"
	local numThreads=100

	#default param run
	#NOTE: we set claim stale = 0/true for some more hardcore testing - this isn't recommended for users, but should work anyway
	echo "Starting swarm runB 1:"
	runFileWriterSwarm $numThreads "$out" "$line" "$mtx" 0
	echo "Done."
	assertOutFileOk "$out" $numThreads "$line"
	#the mutex should have been deleted by the last fileWriter instance
	[ ! -e "$mtx" ]

	#cleanup
	echo "Removing..."
	[ -f "$out" ] && rm -f "$out"

	#other stuff (exc. timeout) should be covered by the b_mtx_try test as b_mtx_waitFor is using that at the moment
}
