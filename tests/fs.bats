#!/usr/bin/env bats
# 
#+Bats tests for the arr module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "fs"

	EMPTY_TEST_DIR="$(mktemp -d)"
	EMPTY_TEST_FILE="$(mktemp)"
}

function teardown {
	[ -n "$EMPTY_TEST_DIR" ] && rm -rf "$EMPTY_TEST_DIR"
	[ -n "$EMPTY_TEST_FILE" ] && rm -f "$EMPTY_TEST_FILE"
}

@test "b_fs_isEmptyDir" {
	runB b_fs_isEmptyDir "/this/should/not/exist"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_fs_isEmptyDir "/tmp"
	[ $status -eq 1 ]
	[ -z "$output" ]

	runB b_fs_isEmptyDir "/tmp/"
	[ $status -eq 1 ]
	[ -z "$output" ]

	runB b_fs_isEmptyDir "/etc/hosts"
	#maybe somewhat strange, but this _directory_ doesn't exist (the file does)
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_fs_isEmptyDir "/etc/hosts/"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#maybe somewhat strange, but this _directory_ doesn't exist (the file does)
	runB b_fs_isEmptyDir "$EMPTY_TEST_FILE"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_fs_isEmptyDir "$EMPTY_TEST_DIR"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "b_fs_getLastModifiedInDays" {
	runB b_fs_getLastModifiedInDays "/tmp/doesntexist_we_hope"
	[ $status -ne 0 ]

	runB b_fs_getLastModifiedInDays "$EMPTY_TEST_FILE"
	[ $status -eq 0 ]
	[ $output -eq 0 ]
	
	runB b_fs_getLastModifiedInDays "$EMPTY_TEST_DIR"
	[ $status -eq 0 ]
	[ $output -eq 0 ]
}

@test "b_fs_getLineCount" {
	runB b_fs_getLineCount "/tmp/nonexisting file !!"
	[ $status -ne 0 ]

	runB b_fs_getLineCount "$EMPTY_TEST_DIR"
	[ $status -ne 0 ]

	runB b_fs_getLineCount "$EMPTY_TEST_FILE"
	[ $status -eq 0 ]
	[ $output -eq 0 ]

	local testFile="$(mktemp)"
	runB b_fs_getLineCount "$testFile"
	[ $status -eq 0 ]
	[ $output -eq 0 ]
	
	echo "line 1 foo bar!" >> "$testFile"
	echo "line 2 foo bar!" >> "$testFile"
	echo "line 3 foo bar!" >> "$testFile"
	runB b_fs_getLineCount "$testFile"
	[ $status -eq 0 ]
	[ $output -eq 3 ]

	rm -f "$testFile"
}

#createFileAfter [seconds] [file]
function createFileAfter {
	local seconds="$1"
	local file="$2"

	sleep $seconds
	touch "$file"
}

@test "b_fs_waitForFile" {
	#NOTE: if any of these cause the test to hang, there's an issue...

	local tfolder="$(mktemp -d)"
	local tfile="$tfolder/waittest"
	touch "$tfile"

	#already existing file
	startTimer
	runB b_fs_waitForFile "$tfile"
	[ $(endTimer) -le 1 ]
	[ $status -eq 0 ]
	[ -z "$output" ]

	startTimer
	runB b_fs_waitForFile "$tfile" 1
	[ $(endTimer) -le 1 ]
	[ $status -eq 0 ]
	[ -z "$output" ]

	startTimer
	runB b_fs_waitForFile "$tfile" 2
	[ $(endTimer) -le 1 ]
	[ $status -eq 0 ]
	[ -z "$output" ]

	#missing file, but created
	echo 1
	rm -f "$tfile"
	echo 2
	startTimer
	echo 3
	createFileAfter 2 "$tfile" 3>&- &
	echo 4
	[ $(endTimer) -le 1 ]
	echo 5
	runB b_fs_waitForFile "$tfile" 7
	local end="$(endTimer)"
	echo "out4: $output"
	echo "end4: $end"
	[ $end -le 4 ]
	[ $status -eq 0 ]
	[ -z "$output" ]
	echo "4 done"

	rm -f "$tfile"
	echo a
	startTimer
	echo b
	createFileAfter 2 "$tfile" 3>&- &
	echo c
	[ $(endTimer) -le 1 ]
	echo d
	runB b_fs_waitForFile "$tfile"
	end="$(endTimer)"
	echo "out5: $output"
	echo "end5: $end"
	[ $end -le 3 ]
	[ $status -eq 0 ]
	[ -z "$output" ]
	echo "5 done"

	#missing file, not created
	rm -f "$tfile"
	startTimer
	runB b_fs_waitForFile "$tfile" 1
	end="$(endTimer)"
	echo "out6: $output"
	echo "end6: $end"
	[ $end -ge 1 ]
	[ $end -le 3 ]
	[ $status -ne 0 ]
	[ -z "$output" ]
	echo "6 done"

	#cleanup
	rm -rf "$tfolder"
}

@test "b_fs_getMountpoints" {
	#invalid devices
	echo 1
	runB b_fs_getMountpoints "holymoly"
	[ $status -ne 0 ]
	echo 2
	runB b_fs_getMountpoints "/dev/holymoly"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 3
	runB b_fs_getMountpoints "/fooBROKEN"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 4
	runB b_fs_getMountpoints "/boot"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 5
	runB b_fs_getMountpoints "/boot/"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 6
	runB b_fs_getMountpoints "boot"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 7
	runB b_fs_getMountpoints "/home"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 8
	runB b_fs_getMountpoints "/home/"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 9
	runB b_fs_getMountpoints "home"
	[ -z "$output" ]
	[ $status -ne 0 ]

	#valid devices
	local dev="$(findmnt -n -o SOURCE -T /)"
	
	echo 10
	runB b_fs_getMountpoints "$dev"
	[[ "$output" == "/" ]]
	[ $status -eq 0 ]
}

#loopDevCleanup [loop device]
function loopDevCleanup {
	local loopDev="$1"

	umount "$loopDev" || { B_ERR="Failed to umount the loop device $loopDev." ; B_E }
	losetup -d "$loopDev" || { B_ERR="Failed to remove the loop device $loopDev." ; B_E }
}

@test "b_fs_createLoopDeviceIfNecessary & b_fs_mountIfNecessary & b_fs_getMountpoints" {
	[[ "$UTD_PW_FREE_USER" != "root" ]] && skip "These tests require password-less root access configured via UTD_PW_FREE_USER in $USER_DATA_FILE."

	local tmpDir="$(mktemp -d)"
	local tmpDir2="$(mktemp -d)"
	[ -d "$tmpDir" ]
	[ -d "$tmpDir2" ]

	local loopFile="$FIXTURES_DIR/fs/ext4loop"
	[ -f "$loopFile" ]
	
	local tmpLoopFile="$(mktemp)"
	cat "$loopFile" > "$tmpLoopFile"
	[ -f "$tmpLoopFile" ]

	local tmpLoopFile2="$(mktemp)"
	cat "$loopFile" > "$tmpLoopFile2"
	[ -f "$tmpLoopFile2" ]

	#some failing tests:
	
	runB b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "/tmp/nonexistingFile_" - "fs" -
	[[ "$output" == *"ERROR"* ]]
	[ $status -ne 0 ]

	runB b_execFuncAs "root" b_fs_mountIfNecessary "/dev/doesntexist" "$tmpDir" - "fs" -
	[[ "$output" == *"ERROR"* ]]
	[ $status -ne 0 ]
	
	#successful tests:
	
	runB b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "$tmpLoopFile" - "fs" -
	local loopDev="$output"
	[ $status -eq 0 ]
	[[ "$output" =~ /dev/loop[0-9]+ ]]

	runB b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "$tmpLoopFile" - "fs" -
	[ $status -eq 0 ]
	[[ "$output" == "$loopDev" ]]

	runB b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "$tmpLoopFile" - "fs" -
	[ $status -eq 0 ]
	[[ "$output" == "$loopDev" ]]

	runB b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "$tmpLoopFile2" - "fs" -
	[ $status -eq 0 ]
	[[ "$output" =~ /dev/loop[0-9]+ ]]
	local loopDev2="$output"
	[[ "$loopDev2" != "$loopDev" ]]

	runB b_fs_getMountpoints "$loopDev"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runB b_execFuncAs "root" b_fs_mountIfNecessary "$loopDev" "$tmpDir" - "fs" -
	[ $status -eq 0 ]
	[[ "$output" == "$tmpDir" ]]

	runB b_execFuncAs "root" b_fs_mountIfNecessary "$loopDev" "$tmpDir" - "fs" -
	[ $status -eq 0 ]
	[[ "$output" == "$tmpDir" ]]

	runB b_execFuncAs "root" b_fs_mountIfNecessary "$loopDev" "$tmpDir2" - "fs" -
	[ $status -eq 0 ]
	[[ "$output" == "$tmpDir" ]]

	runB b_fs_getMountpoints "$loopDev"
	[ $status -eq 0 ]
	[[ "$output" == "$tmpDir" ]]

	local out="$(cat "$tmpDir/SUCCESS.txt")"
	[[ "$out" == "We did it!" ]]

	#cleanup:
	
	runB b_execFuncAs "root" loopDevCleanup "$loopDev" - -
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runB b_fs_getMountpoints "$loopDev"
	[ $status -ne 0 ]
	[ -z "$output" ]

	rm -f "$tmpLoopFile"
	rm -f "$tmpLoopFile2"
	rm -rf "$tmpDir"
	rm -rf "$tmpDir2"

}
