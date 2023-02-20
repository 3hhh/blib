#!/usr/bin/env bats
# 
#+Bats tests for the ui module.
#+
#+Copyright (C) 2022  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "ui"
}

#testPasswordPrompt [ui mode] [password prompt]
function testPasswordPrompt {
local outvar=
local ecode=
b_ui_passwordPrompt "outvar" "$@" > /dev/null
ecode=$?
echo "$outvar"
return $ecode
}

#testPasswordPromptCancel [ui mode] [password prompt]
function testPasswordPromptCancel {
sleep 0.1 | testPasswordPrompt "$@"
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
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR:"* ]]

	runSL testPasswordPromptCancel "tty" "another prompt"
	echo "$output"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR:"* ]]
}
