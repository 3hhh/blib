#!/usr/bin/env bats
# 
#+Bats tests for the multiw module.
#+
#+Copyright (C) 2019  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "multiw"
}

@test "b_multiw_getMaxHangTime & b_multiw_setMaxHangTime" {
	testGetterSetter "b_multiw_setMaxHangTime" 5
}

#assertMultiwFiles [file] [done number] [prog number]
function assertMultiwFiles {
	local file="$1"
	local doneFiles="${2:-1}"
	local progFiles="${3:-0}"

	#count *.multiw.prog files
	local files=
	local cnt=
	files="$(printf "%s\n" "$file".*.multiw.prog)"
	[[ "$files" == "$file.*.multiw.prog" ]] && files=""
	[ -z "$files" ] && cnt=0 || cnt="$(echo "$files" | wc -l)"
	[ $cnt -eq $progFiles ]

	#count *.multiw.done files
	files="$(printf "%s\n" "$file".*.multiw.done)"
	[[ "$files" == "$file.*.multiw.done" ]] && files=""
	[ -z "$files" ] && cnt=0 || cnt="$(echo "$files" | wc -l)"
	[ $cnt -eq $doneFiles ]
}

#testWriteSucc [file] [msg] [# done multiw files] [# prog multiw files]
function testWrite {
	local file="$1"
	local msg="$2"
	local doneFiles="$3"
	local progFiles="$4"
	
	echo "$msg" | { runB b_multiw_write "$file"
	[ $status -eq 0 ]
	[ -z "$output" ]
	}
	runB cat "$file"
	[ $status -eq 0 ]
	[[ "$output" == "$msg" ]]
	[ -h "$file" ]
	assertMultiwFiles "$file" "$doneFiles" "$progFiles"
}

@test "b_multiw_write & b_multiw_remove - basics" {
	#some failing tests
	runB b_multiw_write
	[ $status -ne 0 ]
	[ -n "$output" ]

	echo "bar" | { runB b_multiw_write
	[ $status -ne 0 ]
	[ -n "$output" ]
	}

	#existing files should fail
	local tfile="$(mktemp)"
	echo "bar" | { runB b_multiw_write "$tfile"
	[ $status -ne 0 ]
	[ -n "$output" ]
	}

	#successful tests
	rm -f "$tfile"
	testWrite "$tfile" "bar" 1
	testWrite "$tfile" "foo! master!" 2

	#test timeout removal
	b_multiw_setMaxHangTime 1
	sleep "1.1"
	testWrite "$tfile" "another one" 1
	b_multiw_setMaxHangTime 3

	#test removal
	runB b_multiw_remove "$tfile"
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ ! -e "$tfile" ]
	assertMultiwFiles "$tfile" 0 0

	runB b_multiw_remove "$tfile"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runB b_multiw_remove "/tmp/"
	[ $status -ne 0 ]
	[ -n "$output" ]
	[ -d "/tmp/" ]

	runB b_multiw_remove
	[ $status -ne 0 ]
	[ -n "$output" ]
}

#runPidReader [file] []
function runPidReader {
	local file="$1"
	local line=

	# 20*5*0,1s = 10s reading
	local iter=5
	while [ $iter -gt 0 ] ; do

		#wait if the no writer is done yet
		[ ! -f "$file" ] && continue

		local cnt=0
		local first=""
		while IFS= read -r line ; do
			#we want to read slooowly in order to cause simultaneous writes
			sleep 0.1
			cnt=$(( $cnt +1))
			[ $cnt -eq 1 ] && first=$line && continue
			[[ "$first" != "$line" ]] && B_ERR="[$$] [Reader] Non matching lines: $line (should be $first). File: $file" && B_E
		done < "$file"

		[ $cnt -ne 20 ] && B_ERR="[$$] [Reader] Invalid number of lines identified. File: $file" && B_E

		iter=$(( $iter -1 ))
	done

	exit 0
}

#runPidWriter [file]
function runPidWriter {
	local file="$1"

	# max 20*0,5 = 10s writing
	{ local rand=$(( $RANDOM % 5 ))
	local i=
	for ((i=0; i < 20; i++)) ; do
		sleep "0.$rand"
		echo "$$"
	done
	} | b_multiw_write "$file" || { B_ERR="[$$] [Writer] Writing failed. File: $file" ; B_E }

	exit 0
}

#getMostRecentCandidates [symlink]
#Get a list of the most recent candidates for a valid symlink target (can be multiple as access timestamps are inaccurate/sometimes identical for multiple files).
#returns: list of candidates
function getMostRecentCandidates {
	local syml="$1"

	local file=
	local maxTimestamp=0
	local curTimestamp=
	for file in "$syml".*.multiw.done ; do
		curTimestamp="$( stat -c "%Y" "$file" )" || continue
		[ $curTimestamp -gt $maxTimestamp ] && maxTimestamp=$curTimestamp
	done


	for file in "$syml".*.multiw.done ; do
		curTimestamp="$( stat -c "%Y" "$file" )" || continue
		[ $curTimestamp -eq $maxTimestamp ] && echo "$file"
	done

	return 0
}

@test "b_multiw_write - concurrent writing & reading" {
	local tfile="$(mktemp -u)"
	
	#idea: 10 writers, writing their pid 20 times with some random sleeps in between, 20 readers verifying that the files are consistent
	local i=
	local pids=()

	for ((i=0;i<10;i++)) ; do
		runPidReader "$tfile" &
		pids+=($!)
		runPidReader "$tfile" &
		pids+=($!)
		runPidWriter "$tfile" &
		pids+=($!)
	done

	local pid=
	for pid in "${pids[@]}" ; do
		wait "$pid" || { echo "[${pid}] exit code: $?" ; exit 1 ; }
	done

	echo "Checking whether the most recent has the symlink..."
	local symTarget=
	symTarget="$(readlink -f "$tfile")"
	[ -n "$symTarget" ]
	local mostRecentCandidates="$(getMostRecentCandidates "$tfile")"
	b_listContains "$mostRecentCandidates" "$symTarget"
	echo "Symlink check passed."

	#cleanup
	runB b_multiw_remove "$tfile"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]
}
