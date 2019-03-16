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

@test "b_date_diffSeconds" {
	runSL b_date_diffSeconds "2018-09-20" "2018-09-30"
	[ $status -eq 0 ]
	[[ "$output" == "864000" ]]

	runSL b_date_diffSeconds "inv" "2018-09-30"
	[ $status -ne 0 ]

	runSL b_date_diffSeconds "2018-09-30" "inv"
	[ $status -ne 0 ]

	runSL b_date_diffSeconds "Mon Sep 10 19:41:45 CEST 2018" "2018-09-12 19:41:45 CEST"
	[ $status -eq 0 ]
	[[ "$output" == "172800" ]]
}
