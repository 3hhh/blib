#!/usr/bin/env bats
# 
#+Bats tests for blib main.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.5

#load common test code
load test_common

function setup {
	loadBlib
}

VERSION_STR_REGEX='[0-9\.]+'

@test "B_SCRIPT" {
	[ -n "$B_SCRIPT" ]
	eval "$B_SCRIPT"
	[ $? -eq 0 ]
	#apparently bats copies files to /tmp/bats.*.src before executing them --> we need to check that
	[[ "$B_SCRIPT_NAME" == "bats."*.src ]]
	[[ "$B_SCRIPT_DIR" == "/tmp" ]]
}

@test "b_printStackTrace" {
	runB b_printStackTrace 0
	[ $status -eq 0 ]
	[[ "$output" == *"b_printStackTrace"* ]]

	runB b_printStackTrace
	[ $status -eq 0 ]
	[[ "$output" != *"b_printStackTrace"* ]]
}

##  begin: functions for error testing ####

function straightError {
	B_ERR="1 straightError" ; B_E
	echo "0 straightError"
}

#errorCondX [error = 0]
function errorCond1 {
	[ $1 -ne 0 ] || B_ERR="1 errorCond1" ; B_E
	echo "0 errorCond1"
}

#errorCondX [error = 0]
function errorCond2 {
	[ $1 -eq 0 ] && B_ERR="1 errorCond2" ; B_E
	echo "0 errorCond2"
}

#errorCondX [error = 0]
function errorCond3 {
	if [ 1 -eq 1 ] ; then
		[ $1 -eq 0 ] && B_ERR="1 errorCond3" || [ 0 -eq 0 ] ; B_E
	fi
	echo "0 errorCond3"
}

#errorCondX [error = 0]
function errorCond4 {
	if [ 1 -eq 1 ] ; then
		[ $1 -eq 0 ] && B_ERR="1 errorCond4" || [ 0 -eq 0 ]
		#for exit code testing:
		blib_setExitCode 66
		B_E
		[ $? -ne 66 ] && echo "Exit code test failed!" && exit 66
	fi
	echo "0 errorCond4"
}

#errorCondX [error = 0]
function errorCond5 {
	if [ 1 -eq 1 ] ; then
		[ $1 -ne 0 ] || { B_ERR="1 errorCond5" ; B_E }
	fi
	echo "0 errorCond5"
}

#errorCondX [error = 0]
function errorCond6 {
	if [ 1 -eq 1 ] ; then
		[ $1 -eq 0 ] && { B_ERR="1 errorCond6" ; B_E }
	fi
	echo "0 errorCond6"
}

#errorCondX [error = 0]
function errorCond7 {
	if [ 1 -eq 1 ] ; then
		[ $1 -eq 0 ] && B_ERR="1 errorCond7" && B_E
	fi
	echo "0 errorCond7"
}

#errorCondX [error = 0]
function errorCond8 {
	if [ 1 -eq 1 ] ; then
		[ $1 -eq 0 ] && { B_ERR="1 errorCond8" ; B_E }
	fi
	echo "0 errorCond8"
}

#errorCondX [error = 0]
function errorCond9 {
	[ $1 -eq 0 ] && { B_E ; B_ERR="1 errorCond9" ; B_E }
	echo "0 errorCond9"
}

#errorCondX [error = 0]
function errorCond10 {
	#this cna be a very useful pattern if a function returns a non-zero exit code and maybe something in B_ERR --> check B_ERR first and pass the original error message, then throw a new error if nothing was found
	#--> should definitely work!
	[ $1 -ne 0 ] || { B_E ; B_ERR="1 errorCond10" ; B_E }
	echo "0 errorCond10"
}

#errorCondX [error = 0]
#version with ; after B_E
function errorCond11 {
	if [ 1 -eq 1 ] ; then
		[ $1 -ne 0 ] || { B_ERR="1 errorCond11" ; B_E ; }
	fi
	echo "0 errorCond11"
}

#errorCondX [error = 0]
#version with ; after B_E
function errorCond12 {
	if [ 1 -eq 1 ] ; then
		[ $1 -eq 0 ] && { B_ERR="1 errorCond12" ; B_E ; }
	fi
	echo "0 errorCond12"
}

#nestedErrorCond [func] [error = 0]
function nestedErrorCond {
	$1 $2
	echo "$? nestedErrorCond"
}

#testErrHandler [ret]
function testErrHandler {
	local ret=$1

	#print the error only when not "handled"
	[ $ret -ne 0 ] && >&2 echo "$B_ERR"
	return $ret
}

#testErrorSituation [error] [error reaction]
#[error]: If set to 0, set the error situation; otherwise test the "no error" situation.
#[error reaction]: The error reaction to use (0,1,2 -- see the exit codes at [b_defaultErrorHandler](#b_defaultErrorHandler)).
#[error handler]: The error handler to use. It must at
function testErrorSituation {
	local err=$1
	local reaction=$2

	#define expected status for non-nested
	local eStatus=0
	local eStatusStr="0"
	[ $reaction -ne 0 ] && [ $err -eq 0 ] && eStatus=$B_RC && eStatusStr="1"

	echo ""
	echo "testErrorSituation $err $reaction"

	testGetterSetter "b_setErrorHandler" "testErrHandler $reaction" 1

	runB b_getErrorHandler
	[ $status -eq 0 ]
	[[ "$output" == "testErrHandler $reaction" ]]

	echo "straight error test"
	runB straightError
	echo "STAT: $status"
	echo "OUT: $output"
	if [ $reaction -ne 0 ] ; then
		[ $status -eq $B_RC ]
		[[ "$output" == "1 straightError" ]] #NOTE: absolute == , i.e. it didn't reach the last line
	else
		[ $status -eq 0 ]
		[[ "$output" == "0 straightError" ]]
	fi

	for ((i=1; i < 13; i++)) ; do
		local func="errorCond$i"

		echo "normal: $func $err"
		runB $func "$err"
		echo "STAT: $status"
		echo "OUT: $output"
		[ $status -eq $eStatus ]
		[[ "$output" == "$eStatusStr $func" ]]

		echo "nested: $func $err"
		runB nestedErrorCond "$func" "$err"
		echo "STAT: $status"
		echo "OUT: $output"
		case $reaction in
			0)
			  [[ $status -eq 0 ]]
			  [[ "$output" == "0 $func"$'\n'"0 nestedErrorCond" ]]
			  ;;
			1)
			  [[ $status -eq 0 ]]
			  if [ $err -eq 0 ] ; then
			  	[[ "$output" == "1 $func"$'\n'"$B_RC nestedErrorCond" ]]
			  else
				[[ "$output" == "0 $func"$'\n'"0 nestedErrorCond" ]]
			  fi
			  ;;
			2)
			  if [ $err -eq 0 ] ; then
				[[ $status -eq $B_RC ]]
				[[ "$output" == "1 $func" ]]
			  else
				[[ $status -eq 0 ]]
			  	[[ "$output" == "0 $func"$'\n'"0 nestedErrorCond" ]]
			  fi
			  ;;
			*)
			  [ 1 -eq 0 ]
		esac
	done
}

function testAllErrorSituations {
	testErrorSituation 0 0
	testErrorSituation 0 1
	testErrorSituation 0 2
	testErrorSituation 1 0
	testErrorSituation 1 1
	testErrorSituation 1 2
}

##  end: functions for error testing ####

@test "error handling: B_E, B_ERR, b_setErrorHandler" {
	#do we have aliases available?
	runB shopt -p expand_aliases
	[ $status -eq 0 ]
	[[ "$output" == "shopt -s expand_aliases" ]]
	
	runB alias B_E
	[ $status -eq 0 ]
	[ -n "$output" ]

	#tests
	B_RC=1
	testAllErrorSituations
	B_RC=6
	testAllErrorSituations

	#reset
	B_RC=1
}

function runBE {
	B_E
}

@test "chained errors" {
	#some chained errors followed by a non-error condition **must** cause B_E to exit on the non-error as B_ERR should still be filled
	
	#runB in this environment:
	b_setBE 1
	set +e
	errorCond5 0
	errorCond7 0
	set -e
	b_setBE

	echo 1
	[ -n "$B_ERR" ]
	local oldErr="$B_ERR"

	echo 2
	#this should cause an error:
	runB runBE
	[ $status -ne 0 ]
	echo 2.2
	[[ "$output" == *"$oldErr"* ]]

	echo 3
	[ 1 -eq 1 ] || B_ERR="Never happens."
	#this should also cause an error:
	runB runBE
	[ $status -ne 0 ]
	echo 3.2
	[[ "$output" == *"$oldErr"* ]]
}

@test "b_defaultErrorHandler" {
	runB "b_defaultErrorHandler" 0 0 0
	[ $status -eq 2 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"Stack Trace"* ]]

	runB "b_defaultErrorHandler" 1 0 0
	[ $status -eq 1 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"Stack Trace"* ]]

	runB "b_defaultErrorHandler" 0 1 0
	[ $status -eq 2 ]
	[[ "$output" != *"ERROR"* ]]
	[[ "$output" == *"Stack Trace"* ]]

	runB "b_defaultErrorHandler" 0 0 1
	[ $status -eq 2 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" != *"Stack Trace"* ]]

	runB "b_defaultErrorHandler" 0 1 1
	[ $status -eq 2 ]
	[ -z "$output" ]
}

#should be run with runB
function testResetErrorHandler {
	local cur=""
	local i=

	for ((i=0; i<11; i++)); do
		b_setErrorHandler "$i $i"
	done

	for ((i=10; i>=0; i--)) do
		cur="$(b_getErrorHandler)"
		[[ "$cur" == "$i $i" ]] || exit 33
		b_resetErrorHandler
	done

	cur="$(b_getErrorHandler)"
	[[ "$cur" != "b_defaultErrorHandler" ]] && exit 34
	b_resetErrorHandler
	cur="$(b_getErrorHandler)"
	[[ "$cur" != "b_defaultErrorHandler" ]] && exit 35
	b_resetErrorHandler
	cur="$(b_getErrorHandler)"
	[[ "$cur" != "b_defaultErrorHandler" ]] && exit 36

	return 0
}

@test "b_resetErrorHandler" {
	runB testResetErrorHandler
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

#loudFunc [err out]
function loudFunc {
	local errOut="${1:-1}"
	echo "I print a lot of stuff!"
	[ $errOut -eq 0 ] && B_ERR="loudFunc errored out." && B_E
	echo "Some more foo."
	return 0
}

@test "b_silence" {
	runB b_silence "loudFunc" 1
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_silence "loudFunc" 0
	[ $status -ne 0 ]
	[[ "$output" == "ERROR: loudFunc errored out."$'\n'"Stack Trace:"* ]]

	echo a
	#in current context
	b_setBE 1
	local stat=0
	set +e
	echo b
	b_silence loudFunc 0
	stat=$?
	set -e
	b_resetErrorHandler
	echo c
	[ $stat -ne 0 ]
	echo d
	[[ "$B_ERR" == "loudFunc errored out." ]]
	B_ERR=""
}

@test "b_info" {
	local info="foo bar"
	runB b_info "$info"
	[ $status -eq 0 ]
	[[ "$output" == *"$info"* ]]
}

@test "b_version" {
	runB b_version
	[ $status -eq 0 ]
	[ -n "$output" ]
	[[ "$output" =~ $VERSION_STR_REGEX ]]

	runB b_version 1
	[ $status -eq 0 ]
	[ -n "$output" ]
	[[ "$output" =~ [0-9]+ ]]

	runB b_version 2
	[ $status -eq 0 ]
	[ -n "$output" ]
	[[ "$output" =~ [0-9]+ ]]
}

@test "b_enforceUser" {
	runB b_enforceUser "non existent blal user"
	echo "out: $output"
	[ $status -ne 0 ]

	runB b_enforceUser "$(whoami)"
	echo "out: $output"
	[ $status -eq 0 ]
}

@test "b_isFunction" {
	runB b_isFunction "non existent func"
	[ $status -ne 0 ]
	
	runB b_isFunction "non_existent_func"
	[ $status -ne 0 ]

	local testvar="foo"
	runB b_isFunction testvar
	[ $status -ne 0 ]

	runB b_isFunction "b_isFunction"
	[ $status -eq 0 ]
}

@test "b_getBlibModules" {
	runB b_getBlibModules
	[ $status -eq 0 ]
	[ -n "$output" ]
}


@test "b_listContains" {
local testList=""
#NOTE: read returns 1 on EOF
set +e
read -r -d '' testList << 'EOF'
this is elem 1
elem 2
foo
end?
no!
EOF
set -e
	runB b_listContains "$testList" "foo"
	[ $status -eq 0 ]

	runB b_listContains "$testList" "mother"
	[ $status -ne 0 ]

	runB b_listContains "$testList" "elem 2"
	[ $status -eq 0 ]

	runB b_listContains "$testList" ""
	[ $status -ne 0 ]

	runB b_listContains "$testList" " "
	[ $status -ne 0 ]

	runB b_listContains "$testList" "no!"
	[ $status -eq 0 ]

	runB b_listContains "$testList" "this is elem 1"
	[ $status -eq 0 ]

	runB b_listContains "$testList" "this is not elem 1"
	[ $status -ne 0 ]

	runB b_listContains "$testList" " this is elem 1"
	[ $status -ne 0 ]

	runB b_listContains "$testList" "this is elem 1 "
	[ $status -ne 0 ]
}


@test "b_checkDeps" {
local testDeps=""
local unmetDepsExpected=""
set +e
read -r -d '' testDeps << 'EOF'
unmet dependency 1
bash
unmet dependency 2
sort
EOF

read -r -d '' unmetDepsExpected << 'EOF'
unmet dependency 1
unmet dependency 2
EOF

set -e

	runB b_checkDeps "bash"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_checkDeps ""
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_checkDeps "$testDeps"
	[ $status -ne 0 ]
	[[ "$output" == "$unmetDepsExpected" ]]
}

@test "b_blib_getDeps" {
	runB b_blib_getDeps
	[ $status -eq 0 ]
	[ -n "$output" ]
}

@test "b_isModule" {
	runB b_isModule
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_isModule "cdoc"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_isModule "os/osid"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_isModule "blib"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_isModule "foo/bar/holy"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_isModule "blibnonexistent"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_isModule "blib nonexistent"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_isModule "holy moly"
	[ $status -ne 0 ]
	[ -z "$output" ]
}

@test "b_import" {
	runB b_import "non existing module"
	[ $status -ne 0 ]

	runB b_import "non existing module" 0
	[ $status -ne 0 ]

	runB b_import "non existing module" 1
	[ $status -ne 0 ]

	runB b_import "ini" 0
	[ $status -eq 0 ]

	#2nd try should be ok as well
	runB b_import "ini" 0
	[ $status -eq 0 ]

	#3rd with double source should also be ok
	runB b_import "ini" 1
	[ $status -eq 0 ]

	runB b_import "blib" 1
	[ $status -ne 0 ]

	runB b_import "blib"
	[ $status -ne 0 ]

	runB b_import "os/osid"
	[ $status -eq 0 ]

	runB b_import "os/osid" 1
	[ $status -eq 0 ]
}

#testGenerateStandaloneSucc [ref file] [code file] [out file] [all params]
function testGenerateStandaloneSucc {
	local ref="$1"
	local codeFile="$2"
	local outFile="$3"
	shift
	shift
	shift
	local refPath="$FIXTURES_DIR/blib/$ref"

	echo "code file: $codeFile"
	echo "reference output: $refPath"
	echo "output file: $outFile"

	#static parameters:
	
	#generate file
	echo a
	runB b_generateStandalone "$@"
	echo "$output" > "$codeFile"
	[ $status -eq 0 ]
	[ -n "$output" ]

	#runB the generated file
	echo b
	runB bash "$codeFile"
	echo "$output" > "$outFile"
	[ $status -eq 0 ]
	[ -n "$output" ]

	echo c
	diff "$refPath" "$outFile"

	#dynamic parameters:
	
	echo d
	local func="$1"
	shift
	local pars=()
	for par in "$@" ; do
		[[ "$par" == "-" ]] && break
		pars+=("$par")
		shift
	done

	#generate file
	echo e
	runB b_generateStandalone "$func" "$@"
	echo "$output" > "$codeFile"
	[ $status -eq 0 ]
	[ -n "$output" ]

	#runB the generated file
	echo f
	runB bash "$codeFile" "${pars[@]}"
	echo "$output" > "$outFile"
	[ $status -eq 0 ]
	[ -n "$output" ]
	
	echo g
	diff "$refPath" "$outFile"
}

function depA {
	echo "depA $1"
}

function depB {
	echo "depB $1"
}

function depFunc {
	depA "$1"
	depB "$2"
	echo "depFunc"
	echo "param 1: $1"
	echo "param 2: $2"
}

function funFunc {
	b_import str

	depA "n"
	echo -n "fun prefix: "
	b_str_trim "$1"
}

function genRecursionFunc {
	local codeFile="$1"
	#NOTE: str is already included @standalone, but the import must work anyway
	b_generateStandalone "b_str_trim" "   lots of whitespace was around here!    " - "str" - "b_str_trim" > "$codeFile" || exit 1
	
	local out=""
	out="$(bash "$codeFile")" || exit 1
	if [[ "$out" == "lots of whitespace was around here!" ]] ; then
		echo "ALL GREAT!"
		exit 0
	else
		echo "FAIL :-("
		exit 1
	fi
}

@test "b_generateStandalone" {
	#some fail conditions
	runB b_generateStandalone "non_existent_func" "func param 1" "func param 2" - "fs" -
	[ $status -ne 0 ]
	runB b_generateStandalone "b_isModule" "fs" - "non-existent-module" - "depB"
	[ $status -ne 0 ]
	runB b_generateStandalone "b_isModule" "fs" - "fs" - "non-existent-func"
	[ $status -ne 0 ]

	#success conditions
	runB b_generateStandalone "b_isModule" "fs" - -
	[ $status -eq 0 ]
	#skipping the -
	runB b_generateStandalone "b_isModule" "fs"
	[ $status -eq 0 ]

	local outFile1="$(mktemp)"
	local codeFile1="$(mktemp)"
	local codeFile2="$(mktemp)"
	testGenerateStandaloneSucc "genOut01.txt" "$codeFile1" "$outFile1" "depFunc" "my house" "is at home" - - "depA" "depB"
	testGenerateStandaloneSucc "genOut01.txt" "$codeFile1" "$outFile1" "depFunc" "my house" "is at home" - "fs" "str" - "depA" "depB"
	testGenerateStandaloneSucc "genOut01.txt" "$codeFile1" "$outFile1" "depFunc" "my house" "is at home" - "fs" - "depA" "depB"

	testGenerateStandaloneSucc "genOut02.txt" "$codeFile1" "$outFile1" "depB" - -

	testGenerateStandaloneSucc "genOut03.txt" "$codeFile1" "$outFile1" "funFunc" "    lots of whitespace was around here!      " - "str" - "depA"
	testGenerateStandaloneSucc "genOut03.txt" "$codeFile1" "$outFile1" "funFunc" "   lots of whitespace was around here! " - "fs" "str" - "depA" "depB"

	b_import str
	testGenerateStandaloneSucc "genOut04.txt" "$codeFile1" "$outFile1" "b_str_trim" "   lots of whitespace was around here! " - "fs" "str" - "depA" "depB"
	testGenerateStandaloneSucc "genOut04.txt" "$codeFile1" "$outFile1" "b_str_trim" "   lots of whitespace was around here!" - "str" -
	testGenerateStandaloneSucc "genOut04.txt" "$codeFile1" "$outFile1" "b_str_trim" "   lots of whitespace was around here!" - "str" - "b_str_trim"

	#crazy 2 level recursion (b_generateStandalone call from standalone blib variant)
	testGenerateStandaloneSucc "genOut05.txt" "$codeFile1" "$outFile1" "genRecursionFunc" "$codeFile2" - "str" -
	
	#cleanup
	rm -f "$outFile1"
	rm -f "$codeFile1"
	rm -f "$codeFile2"
}

function meFunc {
	echo "$1_ME IS_$(whoami)_YES ITS_ME_$2"
}

@test "b_execFuncAs" {
	[ -z "$UTD_PW_FREE_USER" ] && skip "UTD_PW_FREE_USER would have to be specified in the user test data file $USER_DATA_FILE for this to work."

	runB whoami
	[ $status -eq 0 ]
	[ -n "$output" ]
	local curUser="$output"

	#some failing tests
	runB b_execFuncAs "$UTD_PW_FREE_USER" "nonExistingFunc" - -
	[ $status -ne 0 ]
	runB b_execFuncAs "$curUser" "nonExistingFunc" - -
	[ $status -ne 0 ]
	runB b_execFuncAs "nonExistingUser" "nonExistingFunc" - -
	[ $status -ne 0 ]
	runB b_execFuncAs "nonExistingUser" "meFunc" - -
	[ $status -ne 0 ]

	#successful tests
	
	#NOTE: we don't need to test it in depth as b_generateStandalone is used internally --> only the user switching is relevant
	runB b_execFuncAs "$UTD_PW_FREE_USER" "meFunc" "Yes" "Or?" - -
	[ $status -eq 0 ]
	[[ "$output" == "Yes_ME IS_${UTD_PW_FREE_USER}_YES ITS_ME_Or?" ]]

	#it should also behave fine with the current user (even if it doesn't make sense)
	runB b_execFuncAs "$curUser" "meFunc" "Yes" "Or?" - -
	[ $status -eq 0 ]
	[[ "$output" == "Yes_ME IS_${curUser}_YES ITS_ME_Or?" ]]

	runB b_execFuncAs "$curUser" "b_fs_getLineCount" "/etc/passwd" - "fs" - "b_fs_getLastModifiedInDays"
	[ $status -eq 0 ]
	[ -n "$output" ]
	[ $output -gt 0 ]
}

@test "command line usage: general" {
	runB "$BLIB"
	[[ "${lines[0]}" == "Usage: blib [command] [command parameters]" ]]
	[ $status -ne 0 ]

	runB "$BLIB" help
	[[ "${lines[0]}" == "Usage: blib [command] [command parameters]" ]]
	[ $status -ne 0 ]

	runB "$BLIB" "foo"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runB "$BLIB" "foo" "bar"
	[ $status -ne 0 ]
	[ -n "$output" ]
}

@test "command line usage: version" {
	runB "$BLIB" version
	[ $status -eq 0 ]
	[ -n "$output" ]
	[[ "$output" =~ $VERSION_STR_REGEX ]]
}

@test "command line usage: info" {
	runB "$BLIB" "info" "blib"
	[ $status -eq 0 ]
	echo 1
	[[ "$output" == *"blib"* ]]
	echo 2
	[[ "$output" == *"b_blib_getDeps"* ]]
	echo 3
	[[ "$output" == *"Dependencies"* ]]
	echo 4

	#check whether dependencies are in the list
	[[ "$output" == *"sort"* ]]
	echo 5
	[[ "$output" == *"dirname"* ]]
	echo 6

	runB "$BLIB" "info" "os/qubes4/dom0"
	[ $status -eq 0 ]
	echo 7
	[[ "$output" == *"os/qubes4/dom0"* ]]
	echo 8
	[[ "$output" == *"b_dom0_getDeps"* ]]
	echo 9
	[[ "$output" == *"Dependencies"* ]]
	[[ "$output" == *"Imports"* ]]
	[[ "$output" == *"Functions"* ]]
	[[ "$output" == *"qvm-prefs"* ]]
	echo 10

	runB "$BLIB" "info" "http"
	[ $status -eq 0 ]
	[[ "$output" == *"Dependencies"* ]]
	[[ "$output" == *"Functions"* ]]
	echo 11

	#check whether dependencies are in the list
	[[ "$output" == *"curl"* ]]
	echo 12

	runB "$BLIB" "blib" "invalid param"
	[ $status -ne 0 ]
	echo 13

	runB "$BLIB" "info" "non existent lib"
	[ $status -ne 0 ]
}

@test "command line usage: list" {
	runB "$BLIB" "list"
	[ $status -eq 0 ]
	[[ "$output" == *"blib"* ]]
	[[ "$output" == *"ini"* ]]
	[[ "$output" == *"os/osid"* ]]

	runB "$BLIB" "list" "invalid param"
	[ $status -ne 0 ]
}

#testGendoc [format] [expected success (0) | failure (1)]
function testGendoc {
	local format="$1"
	local ending="${1:-raw}"
	local exp=$2
	[[ $ending == "raw" ]] && ending="md"
	local out="$DOC_DIR/blib.$ending"
	local outTest="$DOC_DIR/blib_test.$ending"

	[ -f "$out" ] && rm -f "$out"

	echo a
	runB "$BLIB" gendoc $format
	if [ $exp -eq 0 ]; then
		[ $status -eq 0 ]
		[ -f "$out" ]
	else
		[ $status -ne 0 ]
		[ ! -f "$out" ]
	fi

	echo b
	if [[ "$ending" == "md" ]] ; then
		grep -E '^title: ' "$out"
		grep 'LGPLv3' "$out"
		grep ' WITHOUT ANY WARRANTY;' "$out"
	elif [[ "$ending" == "man" ]] ; then
		grep -E '^.SH NAME' "$out"
		grep -E '^.SH DESCRIPTION' "$out"
	fi

	echo c
	[ -f "$outTest" ] && rm -f "$outTest"

	echo d
	runB "$BLIB" gendoc -t $format
	echo "$output"
	if [ $exp -eq 0 ]; then
		[ $status -eq 0 ]
		[ -f "$outTest" ]
	else
		[ $status -ne 0 ]
		[ ! -f "$outTest" ]
	fi
}


@test "command line usage: gendoc" {
	testGendoc "" 0
	echo 1
	testGendoc "raw" 0
	echo 2
	testGendoc "foo" 1
}

@test "command line usage: gendoc with pandoc" {
	skipIfNoPandoc

	testGendoc "pdf" 0
	echo 1
	testGendoc "html" 0
	echo 2
	testGendoc "asd" 1
}
