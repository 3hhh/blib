#!/usr/bin/env bats
# 
#+Bats tests for the dmcrypt module.
#+
#+Copyright (C) 2020  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "dmcrypt"
}

#testInit [ui mode]
function testInit {
	runSC b_dmcrypt_init "$@"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

function rootFunc {
	#NOTE: the state might not get passed to us, i.e. we need to call b_dmcrypt_init again
	if [[ "$1" != "b_dmcrypt_init" ]] ; then
		b_dmcrypt_init "tty" || return 66
	fi
	"$@"
}

#runRoot [function] [function param 1] .. [function param n]
function runRoot {
	runSL b_execFuncAs "root" "rootFunc" "ui" "hash" "dmcrypt" - "$1" - "$@"
}

@test "init" {
	TEST_STATE["DMCRYPT_CONT"]="$(mktemp -u)"
	saveBlibTestState
}

@test "b_dmcrypt_init" {
	testInit
	testInit "tty"
	testInit "gui"
	testInit "auto"

}

@test "b_dmcrypt_getMapperName" {
	b_dmcrypt_init "tty"
	
	runSL b_dmcrypt_getMapperName
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	#nonexisting file must work to support the creation of new containers
	runSL b_dmcrypt_getMapperName "/tmp/nonexist"
	[ $status -eq 0 ]
	[[ "$output" == "blib-dmcrypt-"* ]]
	local id="$output"

	runSL b_dmcrypt_getMapperName "/etc/hosts"
	[ $status -eq 0 ]
	[[ "$output" == "blib-dmcrypt-"* ]]
	[[ "$id" != "$output" ]]
	local id="$output"

	#same ID twice, even in subshell
	(
	runSL b_dmcrypt_getMapperName "/etc/hosts"
	[ $status -eq 0 ]
	[[ "$output" == "$id" ]]
	)

	#same ID even with symbolic links
	run mktemp -u
	[ $status -eq 0 ]
	[ -n "$output" ]
	local symlink="$output"
	ln -s "/etc/hosts" "$symlink"

	runSL b_dmcrypt_getMapperName "$symlink"
	[ $status -eq 0 ]
	[[ "$output" == "$id" ]]

	#cleanup
	rm -f "$symlink"
}

#testOpen [all params except output var]
function testOpen {
	local path="$1"
	local mp="$2"
	shift 2
	local outvar=
	b_dmcrypt_open "$path" "$mp" "outvar" "$@" || exit 1
	[[ "$outvar" == "/dev/mapper/blib-dmcrypt-"* ]] || exit 2
	[ -b "$outvar" ] || exit 3

	if [ -n "$mp" ] ; then
		findmnt "$mp" &> /dev/null || exit 4
	fi
	return 0
}

#testWrite [folder]
#returns: a written file
function testWrite {
	local folder="$1"
	local tfile="$folder/foo"
	echo "foo" > "$tfile" || exit 1
	[ -f "$tfile" ] || exit 2
	echo "$tfile"
}

#removeFiles
function removeFiles {
rm -rf "$@"
}

@test "b_dmcrypt_createLuks & b_dmcrypt_open" {
	skipIfNotRoot
	loadBlibTestState
	b_dmcrypt_init "tty"
	local prompt="Password please:"
	local pw="passw0rd"

	runRoot b_dmcrypt_isOpen "${TEST_STATE["DMCRYPT_CONT"]}"
	[ $status -ne 0 ]
	[ -z "$output" ]
	
	echo "$pw" | {
		runRoot b_dmcrypt_createLuks "${TEST_STATE["DMCRYPT_CONT"]}" "20M" "ext4" "" "$prompt"
		[ $status -eq 0 ]
		}
	[ -f "${TEST_STATE["DMCRYPT_CONT"]}" ]
	local size="$(stat -c "%s" "${TEST_STATE["DMCRYPT_CONT"]}")"
	[ $size -eq 20971520 ]

	runRoot b_dmcrypt_isOpen "${TEST_STATE["DMCRYPT_CONT"]}"
	[ $status -ne 0 ]
	[ -z "$output" ]
	
	#test overwrite
	echo "foobar" | {
		runRoot b_dmcrypt_createLuks "${TEST_STATE["DMCRYPT_CONT"]}" "20M" "" "" "$prompt"
		[ $status -ne 0 ]
		[[ "$output" == *"ERROR"* ]]
		}

	echo "$pw" | {
		runRoot testOpen "${TEST_STATE["DMCRYPT_CONT"]}" "" "$prompt"
		[ $status -eq 0 ]
		[ -z "$output" ]
		}

	runRoot b_dmcrypt_isOpen "${TEST_STATE["DMCRYPT_CONT"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]
	
	#another try with a key file
	local cont="$(mktemp -u)"
	local keyfile="$(mktemp)"
	local mnt="$(mktemp -d)"
	echo "$pw" > "$keyfile"
	runRoot b_dmcrypt_createLuks "$cont" "20M" "ext4" "" "" --key-file "$keyfile"
	[ $status -eq 0 ]
	[ -f "$cont" ]

	runRoot b_dmcrypt_isOpen "$cont"
	[ $status -ne 0 ]
	[ -z "$output" ]
	
	runRoot testOpen "$cont" "$mnt" "" --key-file "$keyfile"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runRoot b_dmcrypt_isOpen "$cont"
	[ $status -eq 0 ]
	[ -z "$output" ]
	
	#test write
	runRoot testWrite "$mnt"
	[ $status -eq 0 ]
	[ -n "$output" ]
	local tfile="$output"
	[ -f "$tfile" ]

	#cleanup
	runRoot b_dmcrypt_close "$cont"
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ ! -e "$tfile" ]

	runRoot b_dmcrypt_isOpen "$cont"
	[ $status -ne 0 ]
	[ -z "$output" ]
	
	runRoot removeFiles "$mnt" "$keyfile" "$cont"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "b_dmcrypt_isOpen" {
	skipIfNotRoot
	loadBlibTestState
	b_dmcrypt_init "tty"

	#tests with valid files were done above & below
	#--> invalid files
	runRoot b_dmcrypt_isOpen "/nonexisting"
	[ $status -ne 0 ]
	[ -z "$output" ]
	
	runRoot b_dmcrypt_isOpen "/nonexisting/nonex"
	[ $status -ne 0 ]
	[ -z "$output" ]
}

@test "b_dmcrypt_close" {
	skipIfNotRoot
	b_dmcrypt_init "tty"
	loadBlibTestState

	runRoot b_dmcrypt_isOpen "${TEST_STATE["DMCRYPT_CONT"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]
	
	runRoot b_dmcrypt_close "${TEST_STATE["DMCRYPT_CONT"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runRoot b_dmcrypt_isOpen "${TEST_STATE["DMCRYPT_CONT"]}"
	[ $status -ne 0 ]
	[ -z "$output" ]
	
	runRoot b_dmcrypt_close "${TEST_STATE["DMCRYPT_CONT"]}"
	[ $status -eq 0 ]
	[[ -z "$output" ]]

	runRoot b_dmcrypt_isOpen "${TEST_STATE["DMCRYPT_CONT"]}"
	[ $status -ne 0 ]
	[ -z "$output" ]
	
	runRoot b_dmcrypt_close "/nonexisting/nonex"
	[ $status -eq 0 ]
	[[ -z "$output" ]]
}

@test "cleanup" {
	loadBlibTestState
	run rm -f "${TEST_STATE["DMCRYPT_CONT"]}"
	clearBlibTestState
}
