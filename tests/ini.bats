#!/usr/bin/env bats
# 
#+Bats tests for the ini module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "ini"
}

#getIniFixture [name]
#[name]: name of the ini fixture to obtain
#returns: full path to the respective file
function getIniFixture {
	echo "${FIXTURES_DIR}/ini/${1}"
}

function runValidDefaultTests {
	local ini="$(getIniFixture "$1")"
	runB b_ini_read "$ini"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#make sure it's available for follow up tests
	forceIniLoad "$ini"
}

function runValid01Tests {
	#default section
	runB b_ini_get "no"
	[ $status -eq 0 ]
	[[ "$output" == "section, but that's ok" ]]

	runB b_ini_getString "no"
	[ $status -eq 0 ]
	[[ "$output" == "section, but that's ok" ]]

	runB b_ini_getInt "no"
	[ $status -ne 0 ]

	runB b_ini_getBool "no"
	[ $status -ne 0 ]

	runB b_ini_getString "is it" ""
	[ $status -eq 0 ]
	[[ "$output" == "really?!" ]]

	runB b_ini_getString "is it" "non existent section"
	[ $status -ne 0 ]

	runB b_ini_getString "" ""
	[ $status -ne 0 ]

	runB b_ini_getInt "number of the beast" "non existent section"
	[ $status -ne 0 ]

	runB b_ini_getInt "number of the beast"
	[ $status -eq 0 ]
	[ $output -eq 666 ]

	runB b_ini_getBool "it rocks"
	[ $status -eq 0 ]
	[ $output -eq 0 ]

	runB b_ini_getInt "port"
	[ $status -eq 0 ]
	[ $output -eq 1 ]

	#sectionName
	runB b_ini_getString "foo" "sectionName"
	[ $status -eq 0 ]
	[[ "$output" == "bar" ]]

	runB b_ini_getInt "port" "sectionName"
	[ $status -eq 0 ]
	[ $output -eq 1234 ]

	runB b_ini_getBool "mega" "sectionName"
	[ $status -eq 0 ]
	[ $output -eq 1 ]

	runB b_ini_getString "organization" "sectionName"
	[ $status -eq 0 ]
	[[ "$output" == "holy moly" ]]

	runB b_ini_getString "non existent" "sectionName"
	[ $status -ne 0 ]

	runB b_ini_getString "file" "sectionName"
	[ $status -eq 0 ]
	[[ "$output" == '"this is a file with ""' ]]

	#section with whitespaces
	runB b_ini_getString "also indented" "section with whitespaces"
	[ $status -eq 0 ]
	[[ "$output" == 'mum I need hääälp!' ]]

	runB b_ini_get "some space above" "section with whitespaces"
	[ $status -eq 0 ]
	[[ "$output" == 'and some afterwards  ' ]]

	runB b_ini_getString "some space above" "section with whitespaces"
	[ $status -eq 0 ]
	[[ "$output" == 'and some afterwards' ]]

	runB b_ini_get ";line!" "section with whitespaces"
	[ $status -ne 0 ]

	#   ahhh Whitespace at the beginning of section name?
	runB b_ini_get "Key" '   ahhh Whitespace at the beginning of section name?'
	[ $status -eq 0 ]
	[[ "$output" == '  VAL_' ]]

	runB b_ini_getString "Key" '   ahhh Whitespace at the beginning of section name?'
	[ $status -eq 0 ]
	[[ "$output" == 'VAL_' ]]

	runB b_ini_getString "mum" '   ahhh Whitespace at the beginning of section name?'
	[ $status -eq 0 ]
	[[ "$output" == 'rocks' ]]

	runB b_ini_get "whitespace before" '   ahhh Whitespace at the beginning of section name?'
	[ $status -eq 0 ]
	[[ "$output" == ' and after the =' ]]

	runB b_ini_getString "whitespace before" '   ahhh Whitespace at the beginning of section name?'
	[ $status -eq 0 ]
	[[ "$output" == 'and after the =' ]]

	runB b_ini_getString "port" '   ahhh Whitespace at the beginning of section name?'
	[ $status -eq 0 ]
	[[ "$output" == 'a string Here' ]]

	runB b_ini_getInt "port" '   ahhh Whitespace at the beginning of section name?'
	[ $status -ne 0 ]

	runB b_ini_getString "dad" '   ahhh Whitespace at the beginning of section name?'
	[ $status -eq 0 ]
	[[ "$output" == 'too' ]]

	runB b_ini_getString "check" '   ahhh Whitespace at the beginning of section name?'
	[ $status -eq 0 ]
	[[ "$output" == 'char'"'"'acter"s^!noesc\rpe\\![muha]' ]]

	#sec_without_content
	runB b_ini_get "port" 'sec_without_content'
	[ $status -ne 0 ]

	runB b_ini_get "dad" 'sec_without_content'
	[ $status -ne 0 ]

	#non existing section
	runB b_ini_get "port" 'non existing'
	[ $status -ne 0 ]
}

function runInvalidDefaultTests {
	local ini="$(getIniFixture "$1")"

	runB b_ini_read "$ini"
	[ $status -ne 0 ]
	[ -n "$output" ]
	[[ "$output" != *"Could not open"* ]]

	#make sure it's available for follow up tests

}

#function to make sure the ini is loaded to the current namespace (runB seems to load it to a subshell)
function forceIniLoad {
	local iniFile="$1"

	#ignore all errors (might be an invalid ini)
	b_setBE 1
	set +e
	b_ini_read "$iniFile" &> /dev/null
	set -e
	#clear error state:
	B_ERR=""
	b_setBE
	return 0
}

function runInvalidDefaultTests {
	local ini="$(getIniFixture "$1")"

	runB b_ini_read "$ini"
	[ $status -ne 0 ]
	[ -n "$output" ]
	[[ "$output" != *"Could not open"* ]]

	#make sure it's available for follow up tests
	forceIniLoad "$ini"

	#further tests after loading
	runB b_ini_get "no"
	[ $status -ne 0 ]

	runB b_ini_getInt "port"
	[ $status -ne 0 ]

	#in different error mode:
	b_setBE 1
	runB b_ini_read "$ini"
	b_setBE
	[ $status -ne 0 ]
	[ -n "$output" ]
	[[ "$output" != *"Could not open"* ]]
}

@test "valid_01.ini" {
	runValidDefaultTests "valid_01.ini"
	runValid01Tests
}

@test "invalid_01.ini" {
	runInvalidDefaultTests "invalid_01.ini"
}

@test "invalid_02.ini" {
	runInvalidDefaultTests "invalid_02.ini"
}

@test "invalid_03.ini" {
	runInvalidDefaultTests "invalid_03.ini"
}

@test "multiple different inis loaded in a row" {
	runInvalidDefaultTests "invalid_01.ini"
	echo 1
	runValidDefaultTests "valid_01.ini"
	echo 2
	runValid01Tests
	echo 3
	runInvalidDefaultTests "invalid_02.ini"
	echo 4
	runInvalidDefaultTests "invalid_03.ini"
	echo 5
	runValidDefaultTests "valid_01.ini"
	echo 6
	runValid01Tests
	echo 7
	runValidDefaultTests "valid_01.ini"
	echo 8
	runValid01Tests
	echo 9
	runInvalidDefaultTests "invalid_02.ini"
	echo 10
	runValidDefaultTests "valid_01.ini"
	echo 11
	runValid01Tests
}


