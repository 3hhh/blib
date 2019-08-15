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

#test variable for the b_execFuncInCurrentContext test
T_GLOB=0

@test "library usage: general" {
	runSC source "$BLIB"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "B_SCRIPT" {
	[ -n "$B_SCRIPT" ]
	eval "$B_SCRIPT"
	[ $? -eq 0 ]
	#apparently bats copies files to /tmp/bats.*.src before executing them --> we need to check that
	[[ "$B_SCRIPT_NAME" == "bats."*.src ]]
	[[ "$B_SCRIPT_DIR" == "/tmp" ]]
}

@test "b_printStackTrace" {
	runSL b_printStackTrace 0
	[ $status -eq 0 ]
	[[ "$output" == *"b_printStackTrace"* ]]

	runSL b_printStackTrace
	[ $status -eq 0 ]
	[[ "$output" != *"b_printStackTrace"* ]]
}

#testEmptyMsg [function] [suffix]
function testEmptyMsg {
	"$1"
	echo "$2"
}

#testMultiMsg [function]
function testMultiMsg {
	local func="$1"

	"$func" "first part" 0 1
	"$func" "middle part" 1 1
	"$func" "last part" 1 0

	"$func" "another" 0 0

	"$func" "and another"

	"$func" "one more" 0 1
	"$func" "time" 1 0
}

@test "b_info & b_error" {
	local info="foo bar"

	runSL b_info "$info"
	[ $status -eq 0 ]
	[[ "$output" == *"INFO"* ]]
	[[ "$output" == *"$info"* ]]

	runSL b_error "$info"
	[ $status -eq 0 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"$info"* ]]

	local expected='INFO: first part
middle part
last part
INFO: another
INFO: and another
INFO: one more
time'
	runSL testMultiMsg "b_info"
	[ $status -eq 0 ]
	[[ "$output" == "$expected" ]]

	runSL testMultiMsg "b_error"
	[ $status -eq 0 ]
	[[ "$output" == "${expected//INFO:/ERROR:}" ]]

	#it should be possible to use b_info/b_error "" to print newlines in the context
	runSL testEmptyMsg "b_info" "$info"
	[ $status -eq 0 ]
	[[ "$output" == $'\n'"$info" ]]

	runSL testEmptyMsg "b_error" "$info"
	[ $status -eq 0 ]
	[[ "$output" == $'\n'"$info" ]]
}

@test "b_defaultMessageHandler & b_setMessageHandler" {
	#b_defaultMessageHandler: already mostly covered by the b_info & b_error test

	local msg="this is a test message"

	runSL b_defaultMessageHandler 0 "$msg"
	[ $status -eq 0 ]
	[[ "$output" == *"INFO:"* ]]
	[[ "$output" == *"$msg"* ]]

	runSL b_defaultMessageHandler 1 "$msg"
	[ $status -eq 0 ]
	[[ "$output" == *"ERROR:"* ]]
	[[ "$output" == *"$msg"* ]]

	runSL b_defaultMessageHandler 1 ""
	[ $status -eq 0 ]
	#actually the output should be a single newline, but bash removes it (--> testEmptyMsg)
	[ -z "$output" ]

	testGetterSetter "b_setMessageHandler" "nonexistingFunc"
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

	runSL b_getErrorHandler
	[ $status -eq 0 ]
	[[ "$output" == "testErrHandler $reaction" ]]

	echo "straight error test"
	runSL straightError
	echo "STAT: $status"
	echo "OUT: $output"
	if [ $reaction -ne 0 ] ; then
		[ $status -eq $B_RC ]
		[[ "$output" == "1 straightError" ]] #NOTE: absolute == , i.e. it didn't reach the last line
	else
		[ $status -eq 0 ]
		[[ "$output" == "0 straightError" ]]
	fi

	local i=
	for ((i=1; i < 13; i++)) ; do
		local func="errorCond$i"

		echo "normal: $func $err"
		runSL $func "$err"
		echo "STAT: $status"
		echo "OUT: $output"
		[ $status -eq $eStatus ]
		[[ "$output" == "$eStatusStr $func" ]]

		echo "nested: $func $err"
		runSL nestedErrorCond "$func" "$err"
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
	runSL shopt -p expand_aliases
	[ $status -eq 0 ]
	[[ "$output" == "shopt -s expand_aliases" ]]
	
	runSL alias B_E
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

function runSLE {
	B_E
}

@test "chained errors" {
	#some chained errors followed by a non-error condition **must** cause B_E to exit on the non-error as B_ERR should still be filled
	
	#runSL in this environment:
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
	runSL runSLE
	[ $status -ne 0 ]
	echo 2.2
	[[ "$output" == *"$oldErr"* ]]

	echo 3
	[ 1 -eq 1 ] || B_ERR="Never happens."
	#this should also cause an error:
	runSL runSLE
	[ $status -ne 0 ]
	echo 3.2
	[[ "$output" == *"$oldErr"* ]]
}

@test "b_defaultErrorHandler" {
	B_ERR="test error message"

	runSL "b_defaultErrorHandler" 0 0 0
	echo "$output"
	[ $status -eq 2 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"test error message"* ]]
	[[ "$output" == *"Stack Trace"* ]]

	runSL "b_defaultErrorHandler" 1 0 0
	echo "$output"
	[ $status -eq 1 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"test error message"* ]]
	[[ "$output" == *"Stack Trace"* ]]

	runSL "b_defaultErrorHandler" 0 1 0
	echo "$output"
	[ $status -eq 2 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" != *"test error message"* ]]
	[[ "$output" == *"Stack Trace"* ]]

	runSL "b_defaultErrorHandler" 0 0 1
	echo "$output"
	[ $status -eq 2 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"test error message"* ]]
	[[ "$output" != *"Stack Trace"* ]]

	runSL "b_defaultErrorHandler" 0 1 1
	echo "$output"
	[ $status -eq 2 ]
	[ -z "$output" ]

	#cleanup
	B_ERR=""
}

#should be run with runSL
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
	B_ERR="foo"
	b_resetErrorHandler
	cur="$(b_getErrorHandler)"
	[[ "$cur" != "b_defaultErrorHandler" ]] && exit 36
	[ -z "$B_ERR" ] || exit 37

	B_ERR="foobar"
	b_resetErrorHandler 1
	[[ "$B_ERR" == "foobar" ]] || exit 38

	return 0
}

@test "b_resetErrorHandler" {
	runSL testResetErrorHandler
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

#multiParFunc [expected number of parameters] [par 1] ... [par n]
function multiParFunc {
	local expected="$1"
	shift
	[ $expected -ne $# ] && { B_ERR="Only found $# many parameters." ; B_E }
	echo "Some $3 printing."
	T_GLOB=1
	return 0
}

@test "b_execFuncInCurrentContext" {
	runSL b_execFuncInCurrentContext "multiParFunc" - 6 "ha ha" "-" "bla my ! way!" "" "ad " "gh !!"
	[ $status -eq 0 ]
	[[ "$output" == "Some bla my ! way! printing." ]]

	T_GLOB=0
	b_execFuncInCurrentContext "multiParFunc" - 6 "ha ha" "-" "bla" "" "ad " "gh !!" > /dev/null
	echo "T_GLOB: $T_GLOB"
	[ $T_GLOB -eq 1 ]
}

@test "b_silence" {
	runSL b_silence "loudFunc" 1
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_silence "loudFunc" 0
	[ $status -ne 0 ]
	[[ "$output" == "ERROR: loudFunc errored out."$'\n'"Stack Trace:"* ]]

	runSL b_silence "multiParFunc" 5 "foo" "a" "-" "cfoobar" ""
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_silence "multiParFunc" 5 "foo" "" "-" "" "finalfoo"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	echo a
	#in current context
	b_setBE 1
	local stat=0
	set +e
	echo b
	b_silence loudFunc 0
	stat=$?
	set -e
	b_resetErrorHandler 1
	echo c
	[ $stat -ne 0 ]
	echo d
	[[ "$B_ERR" == "loudFunc errored out." ]]
	B_ERR=""
}

@test "b_version" {
	runSL b_version
	[ $status -eq 0 ]
	[ -n "$output" ]
	[[ "$output" =~ $VERSION_STR_REGEX ]]

	runSL b_version 1
	[ $status -eq 0 ]
	[ -n "$output" ]
	[[ "$output" =~ [0-9]+ ]]

	runSL b_version 2
	[ $status -eq 0 ]
	[ -n "$output" ]
	[[ "$output" =~ [0-9]+ ]]
}

@test "b_checkVersion" {
	local major="$(b_version 1)"
	local minor="$(b_version 2)"

	#without params (quite useful to check whether any blib version is available)
	runSL b_checkVersion
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "$major" "$minor" "$major" "$minor"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "$major" "$minor"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "" "" "$major" "$minor"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "$((major +1))" "$minor"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "$((major -1))" "$((minor +1))"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "$major" "$((minor +1))"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "$((major -1))" "$((minor -1))"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "$major" "$((minor -1))"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "" "" "$((major +1))" "$minor"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "" "" "$((major -1))" "$((minor +1))"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "" "" "$major" "$((minor +1))"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "" "" "$((major -1))" "$((minor -1))"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "" "" "$major" "$((minor -1))"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "0" "1" "$major" "$((minor -1))"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "0" "1" "$major" "$((minor +1))"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "1" "0" "$major" "$((minor +1))"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "$((major -1))" "$((minor+3))" "$major" "$((minor -1))"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_checkVersion "$((major -1))" "$((minor+3))" "$major" "$minor"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "b_enforceUser" {
	runSL b_enforceUser "non existent blal user"
	echo "out: $output"
	[ $status -ne 0 ]

	runSL b_enforceUser "$(whoami)"
	echo "out: $output"
	[ $status -eq 0 ]
}

@test "b_isFunction" {
	runSL b_isFunction "non existent func"
	[ $status -ne 0 ]
	
	runSL b_isFunction "non_existent_func"
	[ $status -ne 0 ]

	local testvar="foo"
	runSL b_isFunction testvar
	[ $status -ne 0 ]

	runSL b_isFunction "b_isFunction"
	[ $status -eq 0 ]
}

@test "b_getBlibModules" {
	runSL b_getBlibModules
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
	runSL b_listContains "$testList" "foo"
	[ $status -eq 0 ]

	runSL b_listContains "$testList" "mother"
	[ $status -ne 0 ]

	runSL b_listContains "$testList" "elem 2"
	[ $status -eq 0 ]

	runSL b_listContains "$testList" ""
	[ $status -ne 0 ]

	runSL b_listContains "$testList" " "
	[ $status -ne 0 ]

	runSL b_listContains "$testList" "no!"
	[ $status -eq 0 ]

	runSL b_listContains "$testList" "this is elem 1"
	[ $status -eq 0 ]

	runSL b_listContains "$testList" "this is not elem 1"
	[ $status -ne 0 ]

	runSL b_listContains "$testList" " this is elem 1"
	[ $status -ne 0 ]

	runSL b_listContains "$testList" "this is elem 1 "
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

	runSL b_checkDeps "bash"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkDeps ""
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_checkDeps "$testDeps"
	[ $status -ne 0 ]
	[[ "$output" == "$unmetDepsExpected" ]]
}

@test "b_blib_getDeps" {
	runSL b_blib_getDeps
	[ $status -eq 0 ]
	[ -n "$output" ]
}

@test "b_isModule" {
	runSL b_isModule
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_isModule "cdoc"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_isModule "os/osid"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_isModule "blib"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_isModule "foo/bar/holy"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_isModule "blibnonexistent"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_isModule "blib nonexistent"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_isModule "holy moly"
	[ $status -ne 0 ]
	[ -z "$output" ]
}

@test "b_import" {
	runSL b_import "non existing module"
	[ $status -ne 0 ]

	runSL b_import "non existing module" 0
	[ $status -ne 0 ]

	runSL b_import "non existing module" 1
	[ $status -ne 0 ]

	runSC b_import "ini" 0
	[ $status -eq 0 ]

	#2nd try should be ok as well
	runSC b_import "ini" 0
	[ $status -eq 0 ]

	#3rd with double source should also be ok
	runSC b_import "ini" 1
	[ $status -eq 0 ]

	runSC b_import "blib" 1
	[ $status -ne 0 ]

	runSC b_import "blib"
	[ $status -ne 0 ]

	runSC b_import "os/osid"
	[ $status -eq 0 ]

	runSC b_import "os/osid" 1
	[ $status -eq 0 ]
}

#testGenerateStandaloneSucc [ref file] [code file] [out file] [expected status] [all params]
#[expected status]: expected status code when the generated code is run
function testGenerateStandaloneSucc {
	local ref="$1"
	local codeFile="$2"
	local outFile="$3"
	local eStatus="$4"
	shift
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
	runSL b_generateStandalone "$@"
	echo "$output" > "$codeFile"
	[ $status -eq 0 ]
	[ -n "$output" ]

	#runSL the generated file
	echo b
	runSL bash "$codeFile"
	echo "$output" > "$outFile"
	[ $status -eq $eStatus ]
	[ -n "$output" ]

	echo c
	diff "$refPath" "$outFile"

	#dynamic parameters:
	
	echo d
	local func="$1"
	shift
	local mdeps=()
	local fdeps=()
	local pars=()
	local par=
	for par in "$@" ; do
		[[ "$par" == "-" ]] && shift && break
		mdeps+=("$par")
		shift
	done
	for par in "$@" ; do
		[[ "$par" == "-" ]] && shift && break
		fdeps+=("$par")
		shift
	done

	#generate file
	echo e
	runSL b_generateStandalone "$func" "${mdeps[@]}" - "${fdeps[@]}"
	echo "$output" > "$codeFile"
	[ $status -eq 0 ]
	[ -n "$output" ]

	#runSL the generated file
	echo f
	runSL bash "$codeFile" "$@"
	echo "$output" > "$outFile"
	[ $status -eq $eStatus ]
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
	return 33
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
	b_generateStandalone "b_str_trim" "str" - "b_str_trim" - "   lots of whitespace was around here!    " > "$codeFile" || exit 1
	
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
	runSL b_generateStandalone "non_existent_func" "fs" - - "func param 1" "func param 2"
	[ $status -ne 0 ]
	runSL b_generateStandalone "b_isModule" "non-existent-module" - "depB" - "fs"
	[ $status -ne 0 ]
	runSL b_generateStandalone "b_isModule" "fs" - "non-existent-func" - "fs"
	[ $status -ne 0 ]

	#success conditions
	runSL b_generateStandalone "b_isModule" - - "fs"
	[ $status -eq 0 ]

	local outFile1="$(mktemp)"
	local codeFile1="$(mktemp)"
	local codeFile2="$(mktemp)"
	testGenerateStandaloneSucc "genOut01.txt" "$codeFile1" "$outFile1" 33 "depFunc" - "depA" "depB" - "my house" "is at home"
	testGenerateStandaloneSucc "genOut01.txt" "$codeFile1" "$outFile1" 33 "depFunc" "fs" "str" - "depA" "depB" - "my house" "is at home"
	testGenerateStandaloneSucc "genOut01.txt" "$codeFile1" "$outFile1" 33 "depFunc" "fs" - "depA" "depB" - "my house" "is at home"

	testGenerateStandaloneSucc "genOut02.txt" "$codeFile1" "$outFile1" 0 "depB" - -

	testGenerateStandaloneSucc "genOut03.txt" "$codeFile1" "$outFile1" 0 "funFunc" "str" - "depA" - "    lots of whitespace was around here!      "
	testGenerateStandaloneSucc "genOut03.txt" "$codeFile1" "$outFile1" 0 "funFunc" "fs" "str" - "depA" "depB" - "   lots of whitespace was around here! "

	b_import str
	testGenerateStandaloneSucc "genOut04.txt" "$codeFile1" "$outFile1" 0 "b_str_trim" "fs" "str" - "depA" "depB" - "   lots of whitespace was around here! "
	testGenerateStandaloneSucc "genOut04.txt" "$codeFile1" "$outFile1" 0 "b_str_trim" "str" - - "   lots of whitespace was around here!"
	testGenerateStandaloneSucc "genOut04.txt" "$codeFile1" "$outFile1" 0 "b_str_trim" "str" - "b_str_trim" - "   lots of whitespace was around here!"

	#crazy 2 level recursion (b_generateStandalone call from standalonne  blib variant)
	testGenerateStandaloneSucc "genOut05.txt" "$codeFile1" "$outFile1" 0 "genRecursionFunc" "str" - - "$codeFile2"
	
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

	runSL whoami
	[ $status -eq 0 ]
	[ -n "$output" ]
	local curUser="$output"

	#some failing tests
	runSL b_execFuncAs "$UTD_PW_FREE_USER" "nonExistingFunc" - -
	[ $status -ne 0 ]
	runSL b_execFuncAs "$curUser" "nonExistingFunc" - -
	[ $status -ne 0 ]
	runSL b_execFuncAs "nonExistingUser" "nonExistingFunc" - -
	[ $status -ne 0 ]
	runSL b_execFuncAs "nonExistingUser" "meFunc" - -
	[ $status -ne 0 ]

	#successful tests
	
	#NOTE: we don't need to test it in depth as b_generateStandalone is used internally --> only the user switching is relevant
	runSL b_execFuncAs "$UTD_PW_FREE_USER" "meFunc" - - "Yes" "Or?"
	[ $status -eq 0 ]
	[[ "$output" == "Yes_ME IS_${UTD_PW_FREE_USER}_YES ITS_ME_Or?" ]]

	#it should also behave fine with the current user (even if it doesn't make sense)
	runSL b_execFuncAs "$curUser" "meFunc" - - "Yes" "Or?"
	[ $status -eq 0 ]
	[[ "$output" == "Yes_ME IS_${curUser}_YES ITS_ME_Or?" ]]

	runSC b_execFuncAs "$curUser" "b_fs_getLineCount" "fs" - "b_fs_getLastModifiedInDays" - "/etc/passwd"
	[ $status -eq 0 ]
	[ -n "$output" ]
	[ $output -gt 0 ]
}

@test "command line usage: general" {
	runSL "$BLIB"
	[[ "${lines[0]}" == "Usage: blib [command] [command parameters]" ]]
	[ $status -ne 0 ]

	runSL "$BLIB" help
	[[ "${lines[0]}" == "Usage: blib [command] [command parameters]" ]]
	[ $status -ne 0 ]

	runSL "$BLIB" "foo"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL "$BLIB" "foo" "bar"
	[ $status -ne 0 ]
	[ -n "$output" ]
}

@test "command line usage: version" {
	runSL "$BLIB" version
	[ $status -eq 0 ]
	[ -n "$output" ]
	[[ "$output" =~ $VERSION_STR_REGEX ]]
}

@test "command line usage: info" {
	runSL "$BLIB" "info" "blib"
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

	runSL "$BLIB" "info" "os/qubes4/dom0"
	[ $status -eq 0 ]
	echo 7
	[[ "$output" == *"os/qubes4/dom0"* ]]
	echo 8
	[[ "$output" == *"b_dom0_getDeps"* ]]
	echo 9
	[[ "$output" == *"Dependencies"* ]]
	[[ "$output" == *"Imports"* ]]
	[[ "$output" == *"Functions"* ]]
	[[ "$output" == *"qubes-prefs"* ]]
	echo 10

	runSL "$BLIB" "info" "http"
	[ $status -eq 0 ]
	[[ "$output" == *"Dependencies"* ]]
	[[ "$output" == *"Functions"* ]]
	echo 11

	#check whether dependencies are in the list
	[[ "$output" == *"curl"* ]]
	echo 12

	runSL "$BLIB" "blib" "invalid param"
	[ $status -ne 0 ]
	echo 13

	runSL "$BLIB" "info" "non existent lib"
	[ $status -ne 0 ]
}

@test "command line usage: list" {
	runSL "$BLIB" "list"
	[ $status -eq 0 ]
	[[ "$output" == *"blib"* ]]
	[[ "$output" == *"ini"* ]]
	[[ "$output" == *"os/osid"* ]]

	runSL "$BLIB" "list" "invalid param"
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
	runSL "$BLIB" gendoc $format
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
	runSL "$BLIB" gendoc -t $format
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
