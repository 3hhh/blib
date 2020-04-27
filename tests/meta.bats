#!/usr/bin/env bats
# 
#+Bats tests for the meta module.
#+
#+Copyright (C) 2020  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "meta"
}

@test "b_meta_getClearImports" {
	local emptyFile=
	emptyFile="$(mktemp)"

	runSL b_meta_getClearImports "/tmp/nonexisting-path"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_meta_getClearImports "$emptyFile"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_meta_getClearImports "$FIXTURES_DIR/meta/test01"
	[ $status -eq 0 ]
	echo "$output"
	[[ "$output" != *"ERROR"* ]]
	local expected='os/qubes4/dom0
str
should-be-added'
	[[ "$(echo "$output" | sort)" == "$(echo "$expected" | sort)" ]]

	rm -f "$emptyFile"

}

@test "b_meta_getClearDeps" {
	local emptyFile=
	emptyFile="$(mktemp)"

	runSL b_meta_getClearDeps "/tmp/nonexisting-path"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_meta_getClearDeps "$emptyFile"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_meta_getClearDeps "$FIXTURES_DIR/meta/test01"
	[ $status -eq 0 ]
	echo "$output"
	[[ "$output" != *"ERROR"* ]]
	local expected='mount
somecommand
my com_mand-with-numb3r!s
anotherCommand
even a
multiline
dep declaration should
really
really
work
no
spaces
this
as well
my friend'
	[[ "$(echo "$output" | sort)" == "$(echo "$expected" | sort)" ]]

	rm -f "$emptyFile"
}
