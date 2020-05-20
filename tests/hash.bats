#!/usr/bin/env bats
# 
#+Bats tests for the hash module.
#+
#+Copyright (C) 2020  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "hash"
}

@test "b_hash_md5" {
	runSL b_hash_md5 "/etc/nonexistingfile"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_hash_md5 "$FIXTURES_DIR/hash/test01"
	[ $status -eq 0 ]
	[[ "$output" == "c897d1410af8f2c74fba11b1db511e9e" ]]
}

@test "b_hash_md5Str" {
	runSL b_hash_md5Str "hello world!"
	[ $status -eq 0 ]
	[[ "$output" == "c897d1410af8f2c74fba11b1db511e9e" ]]
}
