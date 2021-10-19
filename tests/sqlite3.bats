#!/usr/bin/env bats
#
#+Bats tests for the sqlite3 module.
#+
#+Copyright (C) 2020  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

T_SQLITE3_TESTDB1="${FIXTURES_DIR}/sqlite3/test.db"

function setup {
	loadBlib
	skipIfCommandMissing "sqlite3"
	b_import "sqlite3"
}

@test "b_sqlite3_open & b_sqlite3_getOpen" {
	runSL b_sqlite3_getOpen
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_sqlite3_open
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#it was not opened in the top thread
	runSL b_sqlite3_getOpen
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_sqlite3_open "" 1
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_sqlite3_open "$T_SQLITE3_TESTDB1" 1
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_sqlite3_getOpen
	[ $status -ne 0 ]
	[ -z "$output" ]
}

@test "b_sqlite3_exec & b_sqlite3_close" {
	b_sqlite3_open "$T_SQLITE3_TESTDB1" 1

	runSL b_sqlite3_getOpen
	[ $status -eq 0 ]
	[[ "$output" == "$T_SQLITE3_TESTDB1" ]]

	runSL b_sqlite3_exec "select * from ttable order by str;"
	echo "$output"
	local expected='7|a

newline?\n and other char

text
5|more blabla
3|some text
7|yay \test!'
	[ $status -eq 0 ]
	[[ "$output" == "$expected" ]]

	#cause error
	runSL b_sqlite3_exec "select * from nonexisting;"
	echo "$output"
	[ $status -ne 0 ]
	[[ "$output" != *"ERROR"* ]] #no error from B_E
	[[ "$output" == *"Error: "* ]] #error from sqlite must exist

	#multiline select
	runSL b_sqlite3_exec "select * "$'\n'"from ttable"$'\n'" order by str;"
	[ $status -eq 0 ]
	[[ "$output" == "$expected" ]]

	#no output, effect on following commands
	runSL b_sqlite3_exec ".headers on"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#with command input echo
	runSL b_sqlite3_exec ".headers on" "" 1
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == *".headers on" ]]

	#multiple commands
	runSL b_sqlite3_exec ".mode csv"$'\n'"select * from ttable order by str;"
	output="${output//$'\r'}" #sqlite appears to add carriage returns to csv output
	echo "$output"
	[ $status -eq 0 ]
	local expected2='id,str
7,"a

newline?\n and other char

text"
5,"more blabla"
3,"some text"
7,"yay \test!"'
	[[ "$output" == "$expected2" ]]

	#"hidden" disallowed .output command
	runSL b_sqlite3_exec "select * from ttable order by str;"$'\n'"  .output   /tmp/out.txt"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	#close
	local out="$(mktemp)"
	b_sqlite3_close &> "$out"
	[[ "$(cat "$out")" == "" ]]

	#already closed should be ok
	runSL b_sqlite3_close
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_sqlite3_getOpen
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_sqlite3_exec ".print foobar"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" != *"foobar"* ]]

	#re-open should work
	b_sqlite3_open "$T_SQLITE3_TESTDB1"

	runSL b_sqlite3_getOpen
	[ $status -eq 0 ]
	[[ "$output" == "$T_SQLITE3_TESTDB1" ]]

	runSL b_sqlite3_exec "select * from ttable order by str;"
	[ $status -eq 0 ]
	[[ "$output" == "$expected" ]]

	b_sqlite3_close &> "$out"
	[[ "$(cat "$out")" == "" ]]

	runSL b_sqlite3_getOpen
	[ $status -ne 0 ]
	[ -z "$output" ]

	#make sure no sqlite3 process exists anymore
	run pgrep -a sqlite3
	echo "proc check:"
	echo "$output"
	[ $status -ne 0 ]
	[ -z "$output" ]
}
