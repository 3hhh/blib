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

@test "b_arr_mapsAreEqual" {
	declare -A t1=( ["holy moly"]="foo bar" ["the answer"]=42 [evil]=666 )
	t1Spec="$(declare -p "t1")"
	declare -A t2=( ["holy moly"]="foo bar" ["the answer"]=42 [evil]=667 )
	t2Spec="$(declare -p "t2")"
	declare -A t3=( ["the answer"]=42 [evil]=666 ["holy moly"]="foo bar" )
	t3Spec="$(declare -p "t3")"
	declare -A t4=( [evil]=666 ["holy moly"]="foo bar" )
	t4Spec="$(declare -p "t4")"
	declare -A t5=( ["the answer"]=42 ["holy moly"]="foo bar" [evil]=666  )
	t5Spec="$(declare -p "t5")"

	runB b_arr_mapsAreEqual "$t1Spec" "$t2Spec"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t2Spec" "$t1Spec"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t1Spec" "$t1Spec"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t2Spec" "$t2Spec"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t3Spec" "$t3Spec"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t1Spec" "$t3Spec"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t3Spec" "$t1Spec"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t1Spec" "$t5Spec"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t5Spec" "$t1Spec"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t3Spec" "$t4Spec"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_arr_mapsAreEqual "$t4Spec" "$t3Spec"
	[ $status -ne 0 ]
	[ -z "$output" ]
}
