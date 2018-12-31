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
	b_import "arr"
}

testArr1=("this is" "a test entry" "4" "my dear friends!")

@test "b_arr_join" {
	runB b_arr_join ";-)" "${testArr1[@]}"
	[ $status -eq 0 ]
	[[ "$output" == "this is;-)a test entry;-)4;-)my dear friends!" ]]

	runB b_arr_join ";" "${testArr1[@]}"
	[ $status -eq 0 ]
	[[ "$output" == "this is;a test entry;4;my dear friends!" ]]

	runB b_arr_join "" "${testArr1[@]}"
	[ $status -eq 0 ]
	[[ "$output" == "this isa test entry4my dear friends!" ]]

	runB b_arr_join "MEGA" ""
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "b_arr_contains" {
	runB b_arr_contains "this" "${testArr1[@]}"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_arr_contains "this is" "${testArr1[@]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_contains "4" "${testArr1[@]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_contains "my dear friends!" "${testArr1[@]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_contains "!" "${testArr1[@]}"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_arr_contains "this is even" "${testArr1[@]}"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_arr_contains "this is even" ""
	[ $status -ne 0 ]
	[ -z "$output" ]
}
