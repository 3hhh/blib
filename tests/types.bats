#!/usr/bin/env bats
# 
#+Bats tests for the types module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "types"
}

@test "b_types_isInteger" {
	runSL b_types_isInteger 1234
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger 0
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger "a"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger "33"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger "145."
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger "1.32"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger "1,32"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger "1a32"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger "-9b"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger '0'
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger "-3"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_types_isInteger "8989123213213"
	[ $status -eq 0 ]
	[ -z "$output" ]
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

	#special case: nothing at all
	{ runSL b_types_parseString
	[ $status -eq 0 ]
	[ -z "$output" ]
	} <<< ""

	#cleanup
	rm -f "$tfileMixed1"
	rm -f "$tfileMixed2"
}
