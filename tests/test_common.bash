#!/bin/bash
#
#+Some code and vars meant to be shared across bats tests.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.5
#+

#+### Global Variables ###

#main paths
MAIN_DIR="$(readlink -f "${BATS_TEST_DIRNAME%/tests*}")"
TESTS_DIR="$MAIN_DIR/tests"
DOC_DIR="$MAIN_DIR/doc"
#path to the blib script for sourcing and calls
BLIB="$MAIN_DIR/blib"
FIXTURES_DIR="$TESTS_DIR/fixtures"

#file for static bash varibles that must be set _by the user_ (as they may e.g. be OS specific) in order for some tests to work
#if that file doesn't exist or could not be loaded (USER_DATA_AVAILABLE != 0), these tests should skip
USER_DATA_FILE="$TESTS_DIR/user_test_data.bash"
USER_DATA_AVAILABLE=1
if [ -f "$USER_DATA_FILE" ] ; then
	load "$USER_DATA_FILE" &> /dev/null && USER_DATA_AVAILABLE=0
fi

#for the time measurement functions
TIMER_START=""

#where the TEST_STATE is persisted
TEST_STATE_FILE="/tmp/blib_bats_test_state"

#the current ID for runB
TEST_RUN_ID=1

#+TEST_STATE
#+A map which can be used to create a persistent state across multiple tests.
#+By default, bats creates a new shell environment for each test it runs, resetting all changes to global variables.
#+The state can be managed with the load/save/clearBlibTestState functions below.
declare -gA TEST_STATE

#problem:
#bats/we source blib only in functions (setup()) and not in global scope (makes sense, could have errors)
#aliases defined in functions however are only available after the end of a function (cf. bash(1))
#this here runs in the bats main --> we need to set all aliases here to use them
shopt -s expand_aliases
ALIASES="$(sed -n '/^alias/,/^'"}'"'$/p' "$BLIB")"
eval "$ALIASES"

#+### Functions ###

#+__loadBlib
#+Loads blib for testing.
function loadBlib {
#blib requires +e as some executed commands may fail - especially inside the bats environment
set +e
source "$BLIB"
set -e

#make sure test mode is set to 0 even if bats is used directly
B_TEST_MODE=0
}

#+__skipIfNoUserData 
#+Skip the test if no user data was found.
function skipIfNoUserData {
[ $USER_DATA_AVAILABLE -ne 0 ] && skip "The user test data file $USER_DATA_FILE was not found or could not be loaded."

return 0
}

#+__skipIfNoUserData 
#+Skip the test if pandoc is not installed.
function skipIfNoPandoc {
! command -v pandoc &> /dev/null && skip "pandoc is not installed."

return 0
}

#+__loadBlibTestState
#+Load the [TEST_STATE](#TEST_STATE) with the data that was saved last via [saveBlibState](#saveBlibState). If you want to use [TEST_STATE](#TEST_STATE), call this function during test setup.
function loadBlibTestState {
if [ -f "$TEST_STATE_FILE" ] ; then
	unset TEST_STATE
	source "$TEST_STATE_FILE"
fi

return 0
}

#+__saveBlibState
#+Save the current [TEST_STATE](#TEST_STATE) to make it available for further tests.
function saveBlibTestState {
local tmp="$(declare -p TEST_STATE)"
#for some reason declare -p drops the -g (but we need it)
tmp="${tmp/declare -A/declare -gA}"
echo "$tmp" > "$TEST_STATE_FILE"

return 0
}

#+__clearBlibTestState
#+Clears the current test state and removes its persistent files.
function clearBlibTestState {
unset TEST_STATE
declare -gA TEST_STATE
rm -f "$TEST_STATE_FILE" &> /dev/null

return 0
}

#+__testGetterSetter [setter function] [value to set] [reset]
#+Executes the given setter function _in the current environment_ and makes sure the respective getter function (assumed to have the same name with just a _get_ instead of _set_) returns that value.
#+[setter function]: name of the setter function to call
#+[value to set]: value to set with the setter function
#+[reset]: if set to 0 (default), reset the value back to its original value after testing the setter function
#+returns: nothing, but errors out on test failures
function testGetterSetter {
local setterFunc="$1"
local getterFunc="${setterFunc/set/get}"
local val="$2"
local reset=${3:-0}

#test getter #1
run $getterFunc
[ $status -eq 0 ]
local origVal="$output"

#test setter
run $setterFunc "$val"
[ $status -eq 0 ]
[ -z "$output" ]

#call the setter in the current environment (no subshell:)
$setterFunc "$val"

#test getter #2
run $getterFunc
[ $status -eq 0 ]
[[ "$output" == "$val" ]]

#reset if necessary
if [ $reset -eq 0 ] ; then
	$setterFunc "$origVal"

	#test getter #3
	run $getterFunc
	[ $status -eq 0 ]
	[[ "$output" == "$origVal" ]]
fi

return 0
}

#+__startTimer
#+Start a new time measurement window.
#+returns: nothing
function startTimer {
TIMER_START="$(date +%s)"
}

#+__endTimer
#+Get the differencee in time in seconds since the last time [startTimer](#startTimer) was called.
#+returns: time difference in seconds
function endTimer {
local now="$(date +%s)"
echo $(( $now - $TIMER_START ))
}

#+__runB [bats params]
#+A blib-specific version of the bats run command which prints an identifier for easier debugging. The identifier starts at 1 on the first run call per test and increases with each further run call.
#+[params]: all bats parameters
#+returns: whatever bats run returns
function runB {
	echo "run_$TEST_RUN_ID"
	TEST_RUN_ID=$(( TEST_RUN_ID +1 ))
	run "$@"
	echo "status: $status"
}
