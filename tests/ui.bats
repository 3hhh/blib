#!/usr/bin/env bats
# 
#+Bats tests for the ui module.
#+
#+Copyright (C) 2020  David Hobach  LGPLv3
#+0.2

#load common test code
load test_common

function setup {
	loadBlib
	b_import "ui"
}

#testPasswordPrompt [ui mode] [password prompt]
function testPasswordPrompt {
local outvar=
b_ui_passwordPrompt "outvar" "$@" > /dev/null && echo "$outvar"
}

#testPasswordPromptCancel [ui mode] [password prompt]
function testPasswordPromptCancel {
local expectedPrompt="${2:-"Password: "}"
local tmp="$(mktemp)"

local outvar=
b_ui_passwordPrompt "outvar" "$@" &> "$tmp" &
local pid=$!
sleep 0.3
kill $pid || :
wait $pid 2> /dev/null
[ $? -ne 0 ] || exit 1
[ -z "$outvar" ] || exit 2
local out="$(<"$tmp")"
[[ "$out" == "$expectedPrompt" ]] || { echo "output: $out" ; exit 3 ; }
rm -f "$tmp"
return 0
}

@test "b_ui_passwordPrompt" {
	#NOTE: we don't test GUI mode as this is pretty much impossible without user help
	local pw="password with some säc!al ch?*rs"

	echo "$pw" | {
		runSL testPasswordPrompt "tty"
		[ $status -eq 0 ]
		[[ "$output" == "$pw" ]]
		}

	#simulate cancel
	runSL testPasswordPromptCancel "tty"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL testPasswordPromptCancel "tty" "another prompt"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]
}
