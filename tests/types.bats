#!/usr/bin/env bats
# 
#+Bats tests for the types module.
#+
#+Copyright (C) 2022  David Hobach  LGPLv3
#+0.6

#load common test code
load test_common

function setup {
	loadBlib
	b_import "types"
}

@test "b_types_parseString" {
	#we currently do not test the encoding parameter as it is highly sytem dependent
	
	#generate test data
	local tfileMixed1="$(mktemp)"
	local tfileMixed2="$(mktemp)"
	local randSource="/dev/urandom"
	local origStr1="hello world!"$'\n'"you are my friend, are you not?"$'\n'$'\n'"   foo   "
	echo -n "$origStr1" > "$tfileMixed1"
	dd if="$randSource" bs=1024 count=1 >> "$tfileMixed1" 2> /dev/null
	dd if="$randSource" bs=1024 count=1 > "$tfileMixed2" 2> /dev/null
	echo -n "$origStr1" >> "$tfileMixed2"
	local outNoError=""

	#test
	#hammer it with binary data
	#NOTE: at least UTF-8 has many byte --> character combinations (well filled), so it isn't totally unlikely that we randomly get a valid UTF-8 string (still looking like garbage); the default is ASCII though --> a lot less likely
	local tmp="$(mktemp)"
	local i=
	for ((i=0; i<100; i++)) ; do
		dd if="$randSource" bs=100 count=1 of="$tmp" 2> /dev/null
		echo "input data: $(base64 "$tmp")"
		cat "$tmp" | { runSL b_types_parseString
		[ $status -ne 0 ]
		[[ "$output" != *"ERROR:"* ]]
		}
	done
	
	rm -f "$tmp"

	echo "post binary hammering"

	{ runSL b_types_parseString
	[ $status -ne 0 ]
	[[ "$output" != *"ERROR:"* ]]
	} < "$tfileMixed1"

	{ runSL b_types_parseString
	[ $status -ne 0 ]
	[[ "$output" != *"ERROR:"* ]]
	} < "$tfileMixed2"

	{ runSL b_types_parseString
	[ $status -eq 0 ]
	[[ "$output" == "$origStr1" ]]
	} <<< "$origStr1"

	{ runSL b_types_parseString "" 1
	[ $status -eq 0 ]
	[[ "$output" == "h"$'\n'"y"$'\n'$'\n'" " ]]
	} <<< "$origStr1"

	{ runSL b_types_parseString "" 2
	[ $status -eq 0 ]
	[[ "$output" == "he"$'\n'"yo"$'\n'$'\n'"  " ]]
	} <<< "$origStr1"

	#special case: nothing at all
	{ runSL b_types_parseString
	[ $status -eq 0 ]
	[ -z "$output" ]
	} <<< ""

	{ runSL b_types_parseString
	[ $status -ne 0 ]
	[[ "$output" != *"tätät"* ]]
	[[ "$output" != *"ERROR"* ]]
	} <<< "tätät"

	#test params
	{ runSL b_types_parseString "utf-8"
	[ $status -eq 0 ]
	[[ "$output" == "tätät" ]]
	} <<< "tätät"

	{ runSL b_types_parseString "nonexistent"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
	} <<< "tätät"

	{ runSL b_types_parseString "utf-8" 2
	[ $status -eq 0 ]
	[[ "$output" == "tä" ]]
	} <<< "tätät"

	#test global params
	{ B_TYPES_ENCODING="utf-8"
	runSL b_types_parseString
	[ $status -eq 0 ]
	[[ "$output" == "tätät" ]]
	} <<< "tätät"

	{ B_TYPES_ENCODING="utf-8"
	B_TYPES_MAX_BYTES=2
	runSL b_types_parseString
	[ $status -eq 0 ]
	[[ "$output" == "tä" ]]
	} <<< "tätät"

	#cleanup
	rm -f "$tfileMixed1"
	rm -f "$tfileMixed2"
}

function ret123 {
	echo "$1"
	return 123
}

@test "b_types_str" {
	#the important functionality was already tested in the b_types_parseString tests
	#--> we just test the basics here

	runSL b_types_str ""
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_types_str false
	[ $status -eq 1 ]
	[ -z "$output" ]

	runSL b_types_str ret123 "foobar"
	[ $status -eq 123 ]
	[[ "$output" == "foobar" ]]

	runSL b_types_str echo -n ""
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_types_str dd if=/dev/urandom bs=1 count=20
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_types_str ret123 "tätät"
	[ $status -ne 0 ]
	[ $status -ne 123 ]
	[[ "$output" == *"ERROR"* ]]

	{ B_TYPES_ENCODING="utf-8"
	runSL b_types_str echo "tätät"
	[ $status -eq 0 ]
	[[ "$output" == "tätät" ]]
	}

	{ B_TYPES_ENCODING="utf-8"
	B_TYPES_MAX_BYTES=2
	runSL b_types_str echo -n "tätät"
	[ $status -eq 0 ]
	[[ "$output" == "tä" ]]

	B_TYPES_MAX_BYTES=-1
	runSL b_types_str echo -n "tätät"
	[ $status -eq 0 ]
	[[ "$output" == "tätät" ]]
	}
}

#typeTest [function] [out] [expected status] [arg 1] ... [arg n]
#Run the given function as type test.
#[function]: Name of the function to run.
#[out]: If set to 0, the output must contain an error message, if [expected status] is non-zero and no output otherwise. If set to 1, no output is expected.
#[expected status]: Expected return status.
#[args]: Arguments to pass to the function.
#returns: Nothing.
function typeTest {
	local func="$1"
	local out=$2
	local eStatus=$3
	shift 3

	runSL "$func" "$@"
	[ $status -eq $eStatus ]
	if [ $out -ne 0 ] || [ $eStatus -eq 0 ] ; then
		[ -z "$output" ]
	else
		[[ "$output" == *"ERROR"* ]]
	fi

	return 0
}

#runIntTests [function] [out]
function runIntTests {
	local func="$1"
	local out="$2"

	typeTest "$func" "$out" 0 1234
	typeTest "$func" "$out" 0 0
	typeTest "$func" "$out" 1 "a"
	typeTest "$func" "$out" 1 ""
	typeTest "$func" "$out" 0 33
	typeTest "$func" "$out" 1 "145."
	typeTest "$func" "$out" 1 "1.32"
	typeTest "$func" "$out" 1 "1,32"
	typeTest "$func" "$out" 1 "1a32"
	typeTest "$func" "$out" 1 "-9b"
	typeTest "$func" "$out" 1 "foobar"
	typeTest "$func" "$out" 1 "123"$'\n'"456"
	typeTest "$func" "$out" 0 '0'
	typeTest "$func" "$out" 0 "-3"
	typeTest "$func" "$out" 0 "8989123213213"
	typeTest "$func" "$out" 1 "8989123213213e"
}

@test "b_types_isInteger" {
	runIntTests "b_types_isInteger" 1
}

@test "b_types_assertInteger" {
	runIntTests "b_types_assertInteger" 0

	local msg="my error message"
	runSL b_types_assertInteger "12!" "$msg"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"$msg"* ]]
}

function testInt {
	#the important functionality is already checked by b_types_isInteger & b_types_assert_Integer
	#--> we only check the basics here

	runSL b_types_int ""
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_types_int echo "asd"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_types_int echo "1,23"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_types_int echo "0"
	[ $status -eq 0 ]
	[[ "$output" == "0" ]]

	runSL b_types_int echo "123"
	[ $status -eq 0 ]
	[[ "$output" == "123" ]]

	runSL b_types_int echo "-345"
	[ $status -eq 0 ]
	[[ "$output" == "-345" ]]

	runSL b_types_int dd if=/dev/urandom bs=1 count=20
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_types_int "123"$'\n'"456"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_types_int ret123 "-345"
	[ $status -eq 123 ]
	[[ "$output" == "-345" ]]

	runSL b_types_int ret123 "0"
	[ $status -eq 123 ]
	[[ "$output" == "0" ]]

	runSL b_types_int ret123 "foovar"
	[ $status -ne 123 ]
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
}

@test "b_types_int" {
	testInt

	#not checking for binary _should_ behave as checking for it, but I wouldn't bet on it
	B_TYPES_CHECK_NON_BINARY=1
	testInt
	B_TYPES_CHECK_NON_BINARY=0
}

#runArrayTests [function] [out]
function runArrayTests {
	local func="$1"
	local out="$2"

	typeTest "$func" "$out" 1 1234
	typeTest "$func" "$out" 1 "a b c"
	typeTest "$func" "$out" 1 ''
	emptyarr=()
	typeTest "$func" "$out" 0 "$(declare -p emptyarr)"
	declare -ar arr=("foo" 2 3 "bla")
	typeTest "$func" "$out" 0 "$(declare -p arr)"
	local foo=""
	typeTest "$func" "$out" 1 "$(declare -p foo)"
	local foo=0
	typeTest "$func" "$out" 1 "$(declare -p foo)"
	declare -A map=()
	typeTest "$func" "$out" 1 "$(declare -p map)"
	declare -A map=([0]="foo" [1]="2" [2]="3")
	typeTest "$func" "$out" 1 "$(declare -p map)"
	typeTest "$func" "$out" 0 'declare     -ga     arr=("foo" 2 3 "bla")'
	typeTest "$func" "$out" 0 'declare  -alg    arr=("foo" 2 3 "bla")'
	typeTest "$func" "$out" 0 "declare  -alg    arr='(foo 2 3 bla)'"
	typeTest "$func" "$out" 0 'declare  -alg    arr="(foo 2 3 "bla")"'
	typeTest "$func" "$out" 1 'declare  -xyz    arr=("foo" 2 3 "bla")'
	typeTest "$func" "$out" 1 'declare  -Atg    arr=("foo" 2 3 "bla")'
	typeTest "$func" "$out" 0 'declare arr=("foo" 2 3 "bla") '
	typeTest "$func" "$out" 0 ' arr=("foo" 2 3 "bla")'
	typeTest "$func" "$out" 0 'declare -a arr'
	typeTest "$func" "$out" 0 '  declare -rag arr   '
	typeTest "$func" "$out" 1 '  declare -raxyzg arr   '
	typeTest "$func" "$out" 1 'declare -gA arr'
}

@test "b_types_looksLikeArray" {
	runArrayTests "b_types_looksLikeArray" 1
}

@test "b_types_assertLooksLikeArray" {
	runArrayTests "b_types_assertLooksLikeArray" 0

	local msg="my error message"
	runSL b_types_assertLooksLikeArray "12!" "$msg"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"$msg"* ]]
}

#runMapTests [function] [out]
function runMapTests {
	local func="$1"
	local out="$2"

	typeTest "$func" "$out" 1 1234
	typeTest "$func" "$out" 1 "a b c"
	typeTest "$func" "$out" 1 ''
	emptyarr=()
	typeTest "$func" "$out" 1 "$(declare -p emptyarr)"
	declare -ar arr=("foo" 2 3 "bla")
	typeTest "$func" "$out" 1 "$(declare -p arr)"
	local foo=""
	typeTest "$func" "$out" 1 "$(declare -p foo)"
	local foo=0
	typeTest "$func" "$out" 1 "$(declare -p foo)"
	declare -A map=()
	typeTest "$func" "$out" 0 "$(declare -p map)"
	declare -A map=([0]="foo" [1]="2" [2]="3")
	typeTest "$func" "$out" 0 "$(declare -p map)"
	declare -rA map=([0]="foo" [1]="2" [2]="3")
	typeTest "$func" "$out" 0 "$(declare -p map)"
	typeTest "$func" "$out" 0 'declare     -gA     aRr=([0]="foo" [1]=2 [2]=3 ["holy"]="bla")'
	typeTest "$func" "$out" 0 'declare  -Alg    a_rr=([0]="foo" [1]=2 [2]=3 ["holy"]="bla")'
	typeTest "$func" "$out" 0 "declare  -Alg    a_rr='([0]=foo [1]=2 [2]=3 [holy]=bla)'"
	typeTest "$func" "$out" 0 'declare  -Alg    a_rr="([0]=foo [1]=2 [2]=3 [holy]=bla)"'
	typeTest "$func" "$out" 1 'declare  -xyz    a_rr=([0]="foo" [1]=2 [2]=3 ["holy"]="bla")'
	typeTest "$func" "$out" 1 'declare  -atg    myArr=([0]="foo" [1]=2 [2]=3 ["holy"]="bla")'
	typeTest "$func" "$out" 0 'declare -A another_arr=() '
	typeTest "$func" "$out" 0 'declare -A arr'
	typeTest "$func" "$out" 0 '  declare -rAg arr   '
	typeTest "$func" "$out" 1 '  declare -rAxyzg arr   '
	typeTest "$func" "$out" 1 'declare -ga arr'
}

@test "b_types_looksLikeMap" {
	runMapTests "b_types_looksLikeMap" 1
}

@test "b_types_assertLooksLikeMap" {
	runMapTests "b_types_assertLooksLikeMap" 0

	local msg="my error message"
	runSL b_types_assertLooksLikeMap "12!" "$msg"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
}
