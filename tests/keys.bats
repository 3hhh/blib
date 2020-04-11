#!/usr/bin/env bats
# 
#+Bats tests for the keys module.
#+
#+Copyright (C) 2020  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "keys"
	initGlobalVars
}

function initGlobalVars {
	T_BASE_DIR="/tmp/blib-keys-test"
	T_MTX="/tmp/blib_keys_test_mtx"
	T_APP_ID="my app"
	T_PASS="passw0rd123"

	#hack: we don't use the standard key store, but our own for testing (we don't want to interfere with the official one)
	BLIB_STORE["BLIB_KEYS_DIR"]="$T_BASE_DIR"
	BLIB_STORE["BLIB_KEYS_MTX"]="$T_MTX"
}

function rootFunc {
	#with b_execFuncAs we are in a subshell that requires initialization (no inheritance)
	initGlobalVars || return 65
	#"ni_" for "no init required"
	if [[ "$1" != "b_keys_init" ]] && [[ "$1" != "ni_"* ]] ; then
		blib_keys_initVars "$T_APP_ID" "tty" "" 10000 || return 66
	fi
	"$@"
}

#runRoot [function] [function param 1] .. [function param n]
function runRoot {
	runSC b_execFuncAs "root" "rootFunc" "ui" "dmcrypt" "fs" "proc" "multithreading/mtx" "keys" - "$1" "initGlobalVars" "assertReadOnly" "assertExistentKey" "assertNonExistentKey" - "$@"
}

function ni_printState {
	echo -n "${BLIB_STORE["BLIB_KEYS_STORE"]}"
	echo "${BLIB_STORE["BLIB_KEYS_DIR"]}"
}

function ni_cleanup {
	[[ "$T_BASE_DIR" == "/tmp/"* ]] || return 1
	[[ "$T_MTX" == "/tmp/"* ]] || return 2

	#manual cleanup in case the automatic failed
	local dev=
	dev="/dev/mapper/$(b_dmcrypt_getMapperName "$T_BASE_DIR/keys.lks")"
	umount "$dev" &> /dev/null
	umount "$dev" &> /dev/null
	cryptsetup close "$dev" &> /dev/null

	rm -rf "$T_BASE_DIR"
	rm -rf "$T_MTX"
	[ ! -e "$T_BASE_DIR" ] || return 3
	[ ! -e "$T_MTX" ] || return 4
}

@test "init" {
	skipIfNotRoot
	runRoot ni_cleanup

	#test whether our test setup works
	runRoot ni_printState
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "/tmp/"* ]]
}

function assertOpenFunc {
	local mnt=
	mnt="$(mount | grep "/dev/mapper/" | grep "blib-dmcrypt")" || return 1
	[ -n "$mnt" ] || return 2
	[ -d "$T_BASE_DIR/mnt/rw/$T_APP_ID" ] || return 3
	[ -d "$T_BASE_DIR/mnt/ro/$T_APP_ID" ] || return 4
	return 0
}

function assertOpen {
	runRoot assertOpenFunc
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "b_keys_init" {
	skipIfNotRoot
	runRoot b_keys_init
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	local passTwice="$T_PASS"$'\n'"$T_PASS"

	echo "$passTwice" | {
		runRoot b_keys_init "$T_APP_ID" "" "tty" "" 300
		echo "$output"
		[ $status -eq 0 ]
		[ -z "$output" ]
		}
	[ -f "$T_BASE_DIR/keys.lks" ]
	[ ! -e "$T_MTX" ]
	assertOpen

	local start="$SECONDS"
	#a second init should be no issue and not ask for any password (it is already open)
	#if this hangs, there is an issue
	runRoot b_keys_init "other app"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertOpen

	runRoot b_keys_init "$T_APP_ID" "" "tty"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertOpen

	local duration=$(( $SECONDS - $start ))
	echo "duration: $duration"
	[ $duration -le 1 ]
}

#assertExistentKey [id] [key content]
function assertExistentKey {
	set -e -o pipefail
	local id="$1"
	local content="$2"

	local out=
	out="$(b_keys_get "$id")"
	[ -f "$out" ]
	assertReadOnly "$out"

	out="$(b_keys_getContent "$id")"
	[[ "$out" == "$content" ]]
}

#assertNonExistentKey [id]
function assertNonExistentKey {
	set -e -o pipefail
	local id="$1"

	local out=
	out="$(b_keys_get "$id")"
	[ ! -e "$out" ]
}

function testOperations {
	set -e -o pipefail
	b_setBE 1
echo 1
	local tkey1="$(mktemp)"
	local tkey2="$(mktemp)"
	local keycontent1="this is some test content!"
	local keycontent2="this is more!"
	echo "$keycontent1" > "$tkey1"
	echo "$keycontent2" > "$tkey2"
	local id1="test key"
	local id2="test key 2"
echo 2
	b_keys_add "$id1" "$tkey1"
	b_keys_add "$id2" "$tkey2" 1
echo 3
	[ -f "$tkey1" ]
	[ ! -e "$tkey2" ]
echo 4
	assertExistentKey "$id1" "$keycontent1"
	assertExistentKey "$id2" "$keycontent2"
echo 5
	#attempt overwrite (should fail)
	b_keys_add "$id2" "$tkey1" && exit 2 || :
	assertExistentKey "$id1" "$keycontent1"
	assertExistentKey "$id2" "$keycontent2"
echo 6
	#attemp add from nonexisting file
	b_keys_add "some id" "/tmp/nonexis123545" && exit 3 || :
	assertNonExistentKey "some id"
echo 7
	#invalid get should work according to doc
	local out=
	out="$(b_keys_get "nonexisting")"
	[ -n "$out" ]
	assertReadOnly "$out"
	b_keys_getContent "nonexisting" && exit 7 || :
echo 8
	b_keys_delete "$id2"
	assertNonExistentKey "$id2"
	local bakDir="$T_BASE_DIR/mnt/rw/$T_APP_ID/bak"
	[[ "$(cat "$bakDir/$id2.key")" == "$keycontent2" ]]
	
echo 9
	b_keys_delete "$id1" 1
	assertNonExistentKey "$id1"
	[ ! -e "$bakDir/$id1.key" ]
echo 10
	b_keys_add "$id2" "$tkey1"
	assertNonExistentKey "$id1"
	assertExistentKey "$id2" "$keycontent1"
echo 11
	#attempt nonexisting delete
	b_keys_delete "nonexisting id" && exit 9 || :
	assertNonExistentKey "nonexisting id"
echo 12
	#cleanup
	rm -f "$tkey1"
}

@test "b_keys_add, get, getContent, delete" {
	skipIfNotRoot

	runRoot testOperations
	echo "$output"
	[ $status -eq 0 ]
	[ -n "$output" ]
}

function assertClosedFunc {
	local mname=
	mname="$(b_dmcrypt_getMapperName "$T_BASE_DIR/keys.lks")" || return 1
	cryptsetup status "$mname" > /dev/null && return 2 || :

	#make sure the directories are really empty / nothing written there afterwards
	local dirs=""
	dirs="$(find "$T_BASE_DIR" | sort)" || return 3
	local expectedDirs="$T_BASE_DIR
$T_BASE_DIR/keys.lks
$T_BASE_DIR/mnt
$T_BASE_DIR/mnt/ro
$T_BASE_DIR/mnt/rw"
	if [[ "$dirs" != "$expectedDirs" ]] ; then
		echo "$dirs"
		return 4
	fi

	return 0
}

function assertClosed {
	runRoot assertOpenFunc
	[ $status -ne 0 ]

	runRoot assertClosedFunc
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "b_keys_close" {
	skipIfNotRoot

	assertOpen

	runRoot b_keys_close
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertClosed

	#second close shouldn't hurt
	runRoot b_keys_close
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertClosed

	#make sure that an operation requires a password
	local tfile="$(mktemp)"
	runRoot b_keys_add "test id" "$tfile" < /dev/null
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR: The user aborted the password prompt."* ]]

	#cleanup
	rm -f "$tfile"
}

@test "b_keys multithreading" {
	skipIfNotRoot
	#TODO: ganz am Ende auch assertClosed!
	[ 1 -eq 0 ]
}

@test "cleanup" {
	skipIfNotRoot
	runRoot ni_cleanup
}
