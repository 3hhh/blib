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
	runSL b_fs_isEmptyDir "/this/should/not/exist"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_fs_isEmptyDir "/tmp"
	[ $status -eq 1 ]
	[ -z "$output" ]

	runSL b_fs_isEmptyDir "/tmp/"
	[ $status -eq 1 ]
	[ -z "$output" ]

	runSL b_fs_isEmptyDir "/etc/hosts"
	#maybe somewhat strange, but this _directory_ doesn't exist (the file does)
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_fs_isEmptyDir "/etc/hosts/"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#maybe somewhat strange, but this _directory_ doesn't exist (the file does)
	runSL b_fs_isEmptyDir "$EMPTY_TEST_FILE"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_fs_isEmptyDir "$EMPTY_TEST_DIR"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "b_fs_removeWithOverwrite" {
	runSL b_fs_removeWithOverwrite "/tmp/nonexistingfoo"
	[ $status -ne 0 ]
	[ -n "$output" ]

	local tmp=
	tmp="$(mktemp)"
	runSL dd if=/dev/zero of="$tmp" bs=100K count=1
	[ $status -eq 0 ]
	[ -f "$tmp" ]

	runSL stat -c %s "$tmp"
	[ $status -eq 0 ]
	[[ "$output" == "102400" ]]

	runSL b_fs_removeWithOverwrite "$tmp" "/dev/nonexisting"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_fs_removeWithOverwrite "$tmp"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	[ ! -e "$tmp" ]

	#maybe TODO: test overwrite on ext4 with e.g. extundelete
}

@test "b_fs_getLineCount" {
	runSL b_fs_getLineCount "/tmp/nonexisting file !!"
	[ $status -ne 0 ]

	runSL b_fs_getLineCount "$EMPTY_TEST_DIR"
	[ $status -ne 0 ]

	runSL b_fs_getLineCount "$EMPTY_TEST_FILE"
	[ $status -eq 0 ]
	[ $output -eq 0 ]

	local testFile="$(mktemp)"
	runSL b_fs_getLineCount "$testFile"
	[ $status -eq 0 ]
	[ $output -eq 0 ]
	
	echo "line 1 foo bar!" >> "$testFile"
	echo "line 2 foo bar!" >> "$testFile"
	echo "line 3 foo bar!" >> "$testFile"
	runSL b_fs_getLineCount "$testFile"
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
	runSL b_fs_waitForFile "$tfile"
	[ $(endTimer) -le 1 ]
	[ $status -eq 0 ]
	[ -z "$output" ]

	startTimer
	runSL b_fs_waitForFile "$tfile" 1
	[ $(endTimer) -le 1 ]
	[ $status -eq 0 ]
	[ -z "$output" ]

	startTimer
	runSL b_fs_waitForFile "$tfile" 2
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
	runSL b_fs_waitForFile "$tfile" 7
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
	runSL b_fs_waitForFile "$tfile"
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
	runSL b_fs_waitForFile "$tfile" 1
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
	runSL b_fs_getMountpoints "holymoly"
	[ $status -ne 0 ]
	echo 2
	runSL b_fs_getMountpoints "/dev/holymoly"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 3
	runSL b_fs_getMountpoints "/fooBROKEN"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 4
	runSL b_fs_getMountpoints "/boot"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 5
	runSL b_fs_getMountpoints "/boot/"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 6
	runSL b_fs_getMountpoints "boot"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 7
	runSL b_fs_getMountpoints "/home"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 8
	runSL b_fs_getMountpoints "/home/"
	[ -z "$output" ]
	[ $status -ne 0 ]
	echo 9
	runSL b_fs_getMountpoints "home"
	[ -z "$output" ]
	[ $status -ne 0 ]

	#valid devices
	local dev="$(findmnt -n -o SOURCE -T /)"
	
	echo 10
	runSL b_fs_getMountpoints "$dev"
	[[ "$output" == "/" ]]
	[ $status -eq 0 ]
}

#loopDevCleanup [loop device]
function loopDevCleanup {
	local loopDev="$1"

	umount -A "$loopDev" || { B_ERR="Failed to umount the loop device $loopDev." ; B_E }
	b_fs_removeUnusedLoopDevice "$loopDev" || { B_ERR="Failed to remove the loop device $loopDev." ; B_E }
}

#ensureRemovedLoopDevice [backing file]
function ensureRemovedLoopDevice {
	local bfile="$1"
	local out=
	out="$(losetup -j "$bfile")" || { B_ERR="Failed to execute losetup." ; B_E }
	echo "$out"
	[ -z "$out" ]
}

@test "b_fs_createLoopDeviceIfNecessary & b_fs_mountIfNecessary & b_fs_getMountpoints & b_fs_removeUnusedLoopDevice" {
	skipIfNotRoot

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
	
	runSL b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "fs" - - "/tmp/nonexistingFile_"
	[[ "$output" == *"ERROR"* ]]
	[ $status -ne 0 ]

	runSL b_execFuncAs "root" b_fs_mountIfNecessary "/dev/doesntexist" "fs" - - "$tmpDir"
	[[ "$output" == *"ERROR"* ]]
	[ $status -ne 0 ]

	#successful tests:
	runSL b_execFuncAs "root" b_fs_removeUnusedLoopDevice "fs" - - "/dev/doesntexist"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_execFuncAs "root" b_fs_removeUnusedLoopDevice "fs" - - "/tmp/nonexistingfile"
	[ $status -eq 0 ]
	[ -z "$output" ]
	
	runSL b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "fs" - - "$tmpLoopFile"
	local loopDev="$output"
	[ $status -eq 0 ]
	[[ "$output" =~ /dev/loop[0-9]+ ]]

	runSL b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "fs" - - "$tmpLoopFile"
	[ $status -eq 0 ]
	[[ "$output" == "$loopDev" ]]

	runSL b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "fs" - - "$tmpLoopFile"
	[ $status -eq 0 ]
	[[ "$output" == "$loopDev" ]]

	runSL b_execFuncAs "root" b_fs_removeUnusedLoopDevice "fs" - - "$tmpLoopFile"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_execFuncAs "root" ensureRemovedLoopDevice - - "$tmpLoopFile"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_execFuncAs "root" b_fs_removeUnusedLoopDevice "fs" - - "$tmpLoopFile"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_execFuncAs "root" ensureRemovedLoopDevice - - "$tmpLoopFile"
	echo "$output"
	[ -z "$output" ]
	[ $status -eq 0 ]

	runSL b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "fs" - - "$tmpLoopFile"
	local loopDev="$output"
	[ $status -eq 0 ]
	[[ "$output" =~ /dev/loop[0-9]+ ]]

	runSL b_execFuncAs "root" b_fs_removeUnusedLoopDevice "fs" - - "$loopDev"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_execFuncAs "root" ensureRemovedLoopDevice - - "$tmpLoopFile"
	echo "$output"
	[ -z "$output" ]
	[ $status -eq 0 ]

	runSL b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "fs" - - "$tmpLoopFile"
	local loopDev="$output"
	[ $status -eq 0 ]
	[[ "$output" =~ /dev/loop[0-9]+ ]]

	runSL b_execFuncAs "root" b_fs_createLoopDeviceIfNecessary "fs" - - "$tmpLoopFile2"
	[ $status -eq 0 ]
	[[ "$output" =~ /dev/loop[0-9]+ ]]
	local loopDev2="$output"
	[[ "$loopDev2" != "$loopDev" ]]

	runSL b_fs_getMountpoints "$loopDev"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_execFuncAs "root" b_fs_mountIfNecessary "fs" - - "$loopDev" "$tmpDir"
	[ $status -eq 0 ]
	[[ "$output" == "$tmpDir" ]]

	runSL b_execFuncAs "root" b_fs_removeUnusedLoopDevice "fs" - - "$loopDev"
	[ $status -ne 0 ]
	[ -z "$output" ]
	[ -b "$loopDev" ]

	runSL b_execFuncAs "root" b_fs_removeUnusedLoopDevice "fs" - - "$tmpLoopFile"
	[ $status -ne 0 ]
	[ -z "$output" ]
	[ -b "$loopDev" ]

	runSL b_execFuncAs "root" b_fs_mountIfNecessary "fs" - - "$loopDev" "$tmpDir"
	[ $status -eq 0 ]
	[[ "$output" == "$tmpDir" ]]

	runSL b_execFuncAs "root" b_fs_mountIfNecessary "fs" - - "$loopDev" "$tmpDir2"
	[ $status -eq 0 ]
	[[ "$output" == "$tmpDir" ]]

	local mps="$tmpDir2"$'\n'"$tmpDir"
	local mps2="$tmpDir"$'\n'"$tmpDir2"
	runSL b_execFuncAs "root" b_fs_mountIfNecessary "fs" - - "$loopDev" "$tmpDir2" 0
	[ $status -eq 0 ]
	[[ "$output" == "$mps" ]] || [[ "$output" == "$mps2" ]]

	runSL b_execFuncAs "root" b_fs_mountIfNecessary "fs" - - "$loopDev" "$tmpDir2" 0
	[ $status -eq 0 ]
	[[ "$output" == "$mps" ]] || [[ "$output" == "$mps2" ]]

	runSL b_execFuncAs "root" b_fs_mountIfNecessary "fs" - - "$loopDev" "/tmp/random"
	[ $status -eq 0 ]
	[[ "$output" == "$mps" ]] || [[ "$output" == "$mps2" ]]

	runSL b_fs_getMountpoints "$loopDev"
	[ $status -eq 0 ]
	[[ "$output" == "$mps" ]] || [[ "$output" == "$mps2" ]]

	local out="$(cat "$tmpDir/SUCCESS.txt")"
	[[ "$out" == "We did it!" ]]

	runSL b_execFuncAs "root" b_fs_mountIfNecessary "fs" - - "$loopDev" "/tmp/nonexisting-dir" 0
	[ $status -eq 0 ]
	[[ "$output" == *"/tmp/nonexisting-dir"* ]]

	#cleanup
	runSL b_execFuncAs "root" loopDevCleanup "fs" - - "$loopDev"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_execFuncAs "root" b_fs_removeUnusedLoopDevice "fs" - - "$loopDev2"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_execFuncAs "root" ensureRemovedLoopDevice - - "$tmpLoopFile"
	echo "$output"
	[ -z "$output" ]
	[ $status -eq 0 ]

	runSL b_execFuncAs "root" ensureRemovedLoopDevice - - "$tmpLoopFile2"
	echo "$output"
	[ -z "$output" ]
	[ $status -eq 0 ]

	runSL b_fs_getMountpoints "$loopDev"
	echo "$output"
	[ $status -ne 0 ]
	[ -z "$output" ]

	rm -f "$tmpLoopFile"
	rm -f "$tmpLoopFile2"
	rm -rf "$tmpDir"
	rm -rf "$tmpDir2"
}

@test "b_fs_parseSize" {
	#failing
	runSL b_fs_parseSize "zzM"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_fs_parseSize "10f"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_fs_parseSize "M"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_fs_parseSize "B"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_fs_parseSize "B"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_fs_parseSize "B" 1
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_fs_parseSize ""
	[ $status -ne 0 ]
	[ -n "$output" ]

	#succeeding
	runSL b_fs_parseSize "0"
	echo "out: $output"
	[ $status -eq 0 ]
	[[ "$output" == "0" ]]

	runSL b_fs_parseSize "123"
	[ $status -eq 0 ]
	[[ "$output" == "123" ]]

	runSL b_fs_parseSize "-123"
	[ $status -eq 0 ]
	[[ "$output" == "-123" ]]

	runSL b_fs_parseSize "123K"
	[ $status -eq 0 ]
	[[ "$output" == "125952" ]]

	runSL b_fs_parseSize "123KB"
	[ $status -eq 0 ]
	[[ "$output" == "123000" ]]

	runSL b_fs_parseSize "123M"
	[ $status -eq 0 ]
	[[ "$output" == "128974848" ]]

	runSL b_fs_parseSize "123m"
	[ $status -eq 0 ]
	[[ "$output" == "128974848" ]]

	runSL b_fs_parseSize "123MB"
	[ $status -eq 0 ]
	[[ "$output" == "123000000" ]]

	runSL b_fs_parseSize "123G"
	[ $status -eq 0 ]
	[[ "$output" == "132070244352" ]]

	runSL b_fs_parseSize "1G"
	[ $status -eq 0 ]
	[[ "$output" == "1073741824" ]]

	runSL b_fs_parseSize "-1G"
	[ $status -eq 0 ]
	[[ "$output" == "-1073741824" ]]

	runSL b_fs_parseSize "1KB"
	[ $status -eq 0 ]
	[[ "$output" == "1000" ]]

	runSL b_fs_parseSize "123GB"
	[ $status -eq 0 ]
	[[ "$output" == "123000000000" ]]

	runSL b_fs_parseSize "123gb"
	[ $status -eq 0 ]
	[[ "$output" == "123000000000" ]]

	runSL b_fs_parseSize "123T"
	[ $status -eq 0 ]
	[[ "$output" == "135239930216448" ]]

	runSL b_fs_parseSize "123TB"
	[ $status -eq 0 ]
	[[ "$output" == "123000000000000" ]]
	#skipping peta for now as it is likely to lead to integer overflow

	runSL b_fs_parseSize "-123kb"
	[ $status -eq 0 ]
	[[ "$output" == "-123000" ]]
}
