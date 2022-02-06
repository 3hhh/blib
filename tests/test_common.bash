#!/bin/bash
#
#+Some code and vars meant to be shared across bats tests.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.5
#+

#+### Global Variables ###

#main paths
TESTS_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
MAIN_DIR="${TESTS_DIR%/tests*}"
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

#the current ID for runSL & runSC
TEST_RUN_ID=1

#+TEST_STATE
#+A map which can be used to create a persistent state across multiple tests.
#+By default, bats creates a new shell environment for each test it runs, resetting all changes to global variables.
#+The state can be managed with the load/save/clearBlibTestState functions below.
declare -gA TEST_STATE=()

#problem:
#bats/we source blib only in functions (setup()) and not in global scope (makes sense, could have errors)
#aliases defined in functions however are only available after the end of a function (cf. bash(1))
#this here runs in the bats main --> we need to set all aliases here to use them
shopt -s expand_aliases
ALIASES="$(sed -n '/^alias/,/^'"}'"'$/p' "$BLIB")"
eval "$ALIASES"

#a non-dictionary password for testing purposes
TEST_PASSWORD="j4R-a2_q%jeTzQep6RmgErzl4zmBvF,rZa"

#+### Functions ###

#+loadBlib
#+Loads blib for testing.
#+returns: Nothing
function loadBlib {
#blib requires +e as some executed commands may fail - especially inside the bats environment
set +e
source "$BLIB"
set -e

#make sure test mode is set to 0 even if bats is used directly
B_TEST_MODE=0
}

#+skipIfNoUserData 
#+Skip the test if no user data was found.
#+returns: Nothing.
function skipIfNoUserData {
[ $USER_DATA_AVAILABLE -ne 0 ] && skip "The user test data file $USER_DATA_FILE was not found or could not be loaded."

return 0
}

#+skipIfCommandMissing [command]
#+Skip the test if the given command is not installed.
#+returns: Nothing.
function skipIfCommandMissing {
local cmd="$1"
! command -v "$cmd" &> /dev/null && skip "$cmd is not installed."

return 0
}

#+skipIfNotQubesDom0
#+Skip the test if we're not running inside Qubes OS dom0.
#+returns: Nothing.
function skipIfNotQubesDom0 {
	skipIfNoUserData
	[[ "$UTD_QUBES" != "dom0" ]] && skip "Not running in Qubes OS dom0."

	return 0
}

#+skipIfNotRoot
#+Skip the test if root is not available.
#+returns: Nothing.
function skipIfNotRoot {
[[ "$UTD_PW_FREE_USER" != "root" ]] && skip "This test requires password-less root access configured via UTD_PW_FREE_USER in $USER_DATA_FILE."

return 0
}

#+loadBlibTestState
#+Load the [TEST_STATE](#TEST_STATE) with the data that was saved last via [saveBlibState](#saveBlibState). If you want to use [TEST_STATE](#TEST_STATE), call this function during test setup.
#+returns: Nothing.
function loadBlibTestState {
if [ -f "$TEST_STATE_FILE" ] ; then
	unset TEST_STATE
	source "$TEST_STATE_FILE"
fi

return 0
}

#+saveBlibTestState
#+Save the current [TEST_STATE](#TEST_STATE) to make it available for further tests.
#+returns: Nothing.
function saveBlibTestState {
local tmp="$(declare -p TEST_STATE)"
#for some reason declare -p drops the -g (but we need it)
tmp="${tmp/declare -A/declare -gA}"
echo "$tmp" > "$TEST_STATE_FILE"

return 0
}

#+clearBlibTestState
#+Clears the current test state and removes its persistent files.
#+returns: Nothing.
function clearBlibTestState {
unset TEST_STATE
declare -gA TEST_STATE
rm -f "$TEST_STATE_FILE" &> /dev/null

return 0
}

#+testGetterSetter [setter function] [value to set] [reset]
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
runSL $getterFunc
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

#+startTimer
#+Start a new time measurement window.
#+returns: nothing
function startTimer {
TIMER_START="$(date +%s)"
}

#+endTimer
#+Get the differencee in time in seconds since the last time [startTimer](#startTimer) was called.
#+returns: time difference in seconds
function endTimer {
local now="$(date +%s)"
echo $(( $now - $TIMER_START ))
}

#+funcTimeout [timeout] [function] [args]
#+Run the given function with a timeout inside a subshell.
#+[timeout]: Timeout in seconds after which to terminate the function.
#+[function]: The function to execute.
#+[args]: Function arguments.
#+returns: An exit code of 124, if the function timed out. Otherwise returns whatever the function returned.
function funcTimeout {
local timeout=$1
shift

#NOTE: we also close non-standard FDs for bats, cf. https://github.com/bats-core/bats-core/issues/205#issuecomment-973572596
( b_import "fd" ; b_fd_closeNonStandard ; "$@" ) &
local mainPid=$!

( b_import "fd"
b_fd_closeNonStandard
local cnt=0
while [ $cnt -lt $timeout ] ; do
	[ ! -d /proc/$mainPid ] && exit 1
	cnt=$(( $cnt +1 ))
	sleep 1
done
kill $mainPid &> /dev/null
) &
local killPid=$!

local ret=
wait $mainPid &> /dev/null
ret=$?
[ $ret -eq 143 ] && return 124

wait $killPid
[ $? -eq 0 ] && return 124 || return $ret
}

#printRelevantState
#Prints the parts that appear relevant from the runtime state. May drop parts that it doesn't understand. Should be used by [runStateSaving](#runStateSaving) only.
function printRelevantState {
declare -p | {
	#filter stuff from the state that we don't want to see because it's very volatile
	#for simplicity we also drop every line that doesn't look like a declare on a single line
	#maybe TODO: improve on that, but could be hard as declare -p behaves differently across different bash versions and various separators such as )'" and combinations are all valid depending on the context, i.e. one might have to write an entire parser
        local line=
        local reBeginDecl='^declare [-a-zA-Z]+ ([^=]+)=?(.*)$'
        local reSkip='^(_|IGNORE_.*|BLIB_ERR_.*|B_ERR|RANDOM|SECONDS|BASHPID|FUNCNAME|PIPESTATUS|BASH_.*|BLIB_STORE_VOLATILE|BLIB_IPCM_STORE|BLIB_INI_FILE|B_ARGS|B_ARGS_OPTS|BLIB_ARGS_OPTCNT|B_DELAY_EXECUTED|BLIB_DELAY_CMDS|T_GLOB)$'
	local name=
        while IFS= read -r line ; do
                if [[ "$line" =~ $reBeginDecl ]] ; then
			name="${BASH_REMATCH[1]}"
                        if [[ "$name" =~ $reSkip ]] ; then
                                continue
                        else
				echo "$line"
			fi
                fi
	done
}
}

#runStateSaving [pre execution fd] [post execution fd] [commands ...]
#Run the given commands, but save the state before and afterwards.
#[pre execution fd]: Where to write the state before execution to.
#[post execution fd]: Where to write the state after execution to.
#[commands]: To execute.
#returns: Whatever the executed [commands] returned.
function runStateSaving {
local IGNORE_PRE_FD="$1"
local IGNORE_POST_FD="$2"
shift
shift

#save pre state & make sure post state is saved using an exit trap
#NOTE: we're likely overriding the bats EXIT trap here, but
#  a) bats still has the ERR trap
#  b) we're running inside a subshell (c.f. run()) and bats still has the EXIT trap on the parent
#  c) run sets +eET anyway?!
printRelevantState > "$IGNORE_PRE_FD"
printf -v IGNORE_POST_FD '%q' "$IGNORE_POST_FD"
trap "printRelevantState > $IGNORE_POST_FD" exit

#exec & set proper exit code
"$@"
}

#+runSL [commands]
#+A version of the bats `run` command which makes sure that the bash runtime state does not change after running the given commands (SL = stateless).
#+This *should* be the default method of executing tests for blib.
#+If the given commands are expected to change the state, use [runSC](#runSC) instead. In particular the default bats `run` should almost never be used.
#+Also prints an identifier for easier debugging. The identifier starts at 1 on the first run call per test and increases with each further run call.
#+*WARNING*: As the bats `run` it runs inside a subshell. So don't expect changes to persist.
#+[commands]: The commands to run.
#+returns: whatever bats run returns
function runSL {
local stateBefore=
local stateAfter=

stateBefore="$(mktemp)"
stateAfter="$(mktemp)"
runSC runStateSaving "$stateBefore" "$stateAfter" "$@"
echo "state before: $stateBefore"
echo "state after: $stateAfter"
diff --suppress-common-lines "$stateBefore" "$stateAfter"
rm -f "$stateBefore" "$stateAfter"
}

#+runSC [commands]
#+A version of the bats `run` command which ignore changes to the bash runtime state (SC = state changing).
#+If the given commands are expected to be stateless, use [runSL](#runSL) instead. In particular the default bats `run` should almost never be used.
#+Also prints an identifier for easier debugging. The identifier starts at 1 on the first run call per test and increases with each further run call.
#+*WARNING*: As the bats `run` it runs inside a subshell. So don't expect changes to persist.
#+[commands]: The commands to run.
#+returns: whatever bats run returns
function runSC {
echo "run_${TEST_RUN_ID}: $@"
TEST_RUN_ID=$(( TEST_RUN_ID +1 ))
run "$@"
echo "status: $status"
}

#+assertReadOnly [path]
#+Assert that the given file or directory is read-only by attempting to write to it.
#+[path]: Full path to a file or directory. If it is not r/o, it may be changed.
#+returns: A zero exit code, if the path is r/o.
#+@B_E
function assertReadOnly {
local path="$1"

if [ -d "$path" ] ; then
	touch "$path/testfile" &> /dev/null && return 1 || return 0
elif [ -f "$path" ] ; then
	touch "$path" &> /dev/null && return 2 || return 0
elif [ ! -e "$path" ] ; then
	mkdir -p "$path" &> /dev/null && return 3 || return 0
else
	return 4
fi
}
