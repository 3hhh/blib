#!/usr/bin/env bats
# 
#+Bats tests for the wm module.
#+
#+Copyright (C) 2020  David Hobach  LGPLv3
#+0.1

#load common test code
load test_common

function setup {
	loadBlib
	skipIfCommandMissing "wmctrl"
	b_import "wm"
}

#assertCorrectWindowProperties [b_wm_getActiveWindowProperties output]
#The variable is assumed to be named "out".
function assertCorrectWindowProperties {
	eval "$1"

	local val=
	declare -a ids=()
	for key in "${!out[@]}" ; do
		[[ "$key" == *"_id" ]] && ids+=("${out["$key"]}")
	done

	echo 1
	[ ${#out[@]} -eq $(( ${#ids[@]} * 10 )) ]

	local id=
	local dre='^[0-9]+$'
	for id in "${ids[@]}" ; do
		echo 2
		[[ "${out["${id}_id"]}" == "$id" ]]
		echo 3
		[[ "${out["${id}_desktop"]}" =~ $dre ]]
		echo 4
		[[ "${out["${id}_pid"]}" =~ $dre ]]
		echo 5
		[[ "${out["${id}_x"]}" =~ $dre ]]
		echo 6
		[[ "${out["${id}_y"]}" =~ $dre ]]
		echo 7
		[[ "${out["${id}_width"]}" =~ $dre ]]
		echo 8
		[[ "${out["${id}_height"]}" =~ $dre ]]
		echo 9
		[ -n "${out["${id}_class"]}" ]
		echo 10
		[[ "${out["${id}_class"]}" != "N/A" ]]
		echo 11
		[[ "${out["${id}_client"]+exists}" == "exists" ]]
		echo 12
		[[ "${out["${id}_client"]}" != "N/A" ]]
		echo 13
		[[ "${out["${id}_title"]+exists}" == "exists" ]]
		echo 14
		[[ "${out["${id}_title"]}" != "N/A" ]]
		echo 15
	done
}

@test "b_wm_getActiveWindowProperties" {
	runSL b_wm_getActiveWindowProperties
	[ $status -ne 0 ]
	[[ "$output" == "ERROR"* ]]

	runSL b_wm_getActiveWindowProperties "out"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "declare -A out"* ]]
	assertCorrectWindowProperties "$output"
}
