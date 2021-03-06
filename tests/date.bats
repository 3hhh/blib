#!/usr/bin/env bats
# 
#+Bats tests for the date module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "date"
}

@test "b_date_add" {
	runSL b_date_add "inv date" 5 "s" "%Y-%m-%d %T"
	[ $status -ne 0 ]

	runSL b_date_add "2018-09-30" 14 "k" "%D"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_date_add "2018-09-30" 14 "d"
	[ $status -eq 0 ]
	[[ "$output" != *"ERROR"* ]]

	runSL b_date_add "2018-09-30 00:00:00" 13 "s" "%Y-%m-%d %T"
	[ "$status" -eq 0 ]
	[[ "$output" == "2018-09-30 00:00:13" ]]

	runSL b_date_add "2018-09-30 00:00:00" 13 "" "%Y-%m-%d %T"
	[ "$status" -eq 0 ]
	[[ "$output" == "2018-09-30 00:00:13" ]]

	runSL b_date_add "2018-09-30 00:00:00" 13 "m" "%Y-%m-%d %T"
	[ "$status" -eq 0 ]
	[[ "$output" == "2018-09-30 00:13:00" ]]

	runSL b_date_add "2018-09-30 00:00:00" 13 "h" "%Y-%m-%d %T"
	[ "$status" -eq 0 ]
	[[ "$output" == "2018-09-30 13:00:00" ]]

	runSL b_date_add "2018-09-20 00:00:00" 25 "h" "%Y-%m-%d %T"
	[ "$status" -eq 0 ]
	[[ "$output" == "2018-09-21 01:00:00" ]]

	runSL b_date_add "2018-09-20 00:00:00" 7 "d" "%Y-%m-%d %T"
	[ "$status" -eq 0 ]
	[[ "$output" == "2018-09-27 00:00:00" ]]

	runSL b_date_add "2018-09-20 00:00:00" -7 "d" "%Y-%m-%d %T"
	[ "$status" -eq 0 ]
	[[ "$output" == "2018-09-13 00:00:00" ]]

	runSL b_date_add "2018-09-20 00:00:00" -7 "h" "%Y-%m-%d %T"
	[ "$status" -eq 0 ]
	[[ "$output" == "2018-09-19 17:00:00" ]]
}

@test "b_date_addDays" {
	runSL b_date_addDays "2018-09-30" 14 "%D"
	[ $status -eq 0 ]
	[[ "$output" == "10/14/18" ]]

	runSL b_date_addDays "2018-09-30" 14 "%D" 0
	[ $status -eq 0 ]
	[[ "$output" == "10/14/18" ]]

	runSL b_date_addDays "Mon Sep 10 19:41:45 CEST 2018" 5 "%Y-%m-%d %T" 0
	[ $status -eq 0 ]
	[[ "$output" == "2018-09-15 17:41:45" ]]

	runSL b_date_addDays "Mon Sep 10 19:41:45 CEST 2018" -5 "%Y-%m-%d %T" 0
	[ $status -eq 0 ]
	[[ "$output" == "2018-09-05 17:41:45" ]]

	runSL b_date_addDays "@1509321601" 1 "%Y-%m-%d %T" 0
	[ $status -eq 0 ]
	[[ "$output" == "2017-10-31 00:00:01" ]]

	runSL b_date_addDays "@1509321601" 1 "%s"
	[ $status -eq 0 ]
	[[ "$output" == "1509408001" ]]

	runSL b_date_addDays "inv date 2019" 5 "%Y-%m-%d %T"
	[ $status -ne 0 ]
}

@test "b_date_diff" {
	runSL b_date_diff "2018-09-20" "2018-09-30"
	[ $status -eq 0 ]
	[[ "$output" == "864000" ]]

	runSL b_date_diff "2018-09-20" "2018-09-30" "d"
	[ $status -eq 0 ]
	[[ "$output" == "10" ]]

	runSL b_date_diff "2018-09-20" "2018-09-30" "h"
	[ $status -eq 0 ]
	[[ "$output" == "240" ]]

	runSL b_date_diff "2018-09-20" "2018-09-30" "m"
	[ $status -eq 0 ]
	[[ "$output" == "14400" ]]

	runSL b_date_diff "inv" "2018-09-30"
	[ $status -ne 0 ]

	runSL b_date_diff "2018-09-30" "inv"
	[ $status -ne 0 ]

	runSL b_date_diff "Mon Sep 10 19:41:45 CEST 2018" "2018-09-12 19:41:45 CEST"
	[ $status -eq 0 ]
	[[ "$output" == "172800" ]]
}

@test "b_date_getFileModAge" {
	local tfile=
	tfile="$(mktemp)"
	local tdir=
	tdir="$(mktemp -d)"

	runSL b_date_getFileModAge "/tmp/doesntexist_we_hope"
	[ $status -ne 0 ]

	runSL b_date_getFileModAge "$tfile" "h"
	[ $status -eq 0 ]
	[ $output -eq 0 ]

	runSL b_date_getFileModAge "$tdir" "h"
	[ $status -eq 0 ]
	[ $output -eq 0 ]

	sleep 1
	runSL b_date_getFileModAge "$tfile" "s"
	[ $status -eq 0 ]
	[ $output -ge 1 ]

	runSL b_date_getFileModAge "$tdir"
	[ $status -eq 0 ]
	[ $output -ge 1 ]

	runSL b_date_getFileModAge "$tdir" "m"
	[ $status -eq 0 ]
	[ $output -eq 0 ]

	runSL b_date_getFileModAge "$tfile" "h"
	[ $status -eq 0 ]
	[ $output -eq 0 ]

	runSL b_date_getFileModAge "$tdir" "d"
	[ $status -eq 0 ]
	[ $output -eq 0 ]

	#cleanup
	rm -f "$tfile"
	rm -rf "$tdir"
}
