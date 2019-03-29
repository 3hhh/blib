#!/usr/bin/env bats
# 
#+Bats tests for the os/qubes4/dom0 module.
#+
#+**Important**: This is _test_ code and should not be used in production environments as quite often it is lacking checks wrt untrusted VM output from e.g. [b_dom0_qvmRun](#b_dom0_qvmRun). Developers should follow the standards outlined there for their projects.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.4

#load common test code
load ../../test_common

#those two will contain names of started VMs which can be used for testing (created & started in b_dom0_startDispVM test)
#TEST_STATE["DOM0_TESTVM_1"]=""
#TEST_STATE["DOM0_TESTVM_2"]=""

#event counter for b_dom0_enterEventLoop
T_EVENT_CNT=0

#getDom0Fixture [file name]
function getDom0Fixture {
	echo "$FIXTURES_DIR/os/qubes4/dom0/$1"
}

function setup {
	skipIfNotQubesDom0
	loadBlib
	b_import "os/qubes4/dom0"

	#we use the test state to store the test dispvms between tests
	loadBlibTestState
}

function skipIfNoTestVMs {
	if [ -z "${TEST_STATE["DOM0_TESTVM_1"]}" ] || [ -z "${TEST_STATE["DOM0_TESTVM_2"]}" ] ; then
		skip "The b_dom0_startDispVM test failed to start VMs for testing."
	fi

	[ -z "$UTD_QUBES_TESTVM" ] && skip "Please specify a static disposable test VM as UTD_QUBES_TESTVM in your user data file $USER_DATA_FILE."
	[ -z "$UTD_QUBES_TESTVM_PERSISTENT" ] && skip "Please specify a static non-disposable test VM as UTD_QUBES_TESTVM_PERSISTENT in your user data file $USER_DATA_FILE."

	return 0
}

@test "b_dom0_startDispVM" {
	runSL b_dom0_startDispVM "non existing template"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_startDispVM "non-existing-template"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#start the needed test VMs
	runSL b_dom0_startDispVM "$UTD_QUBES_DISPVM_TEMPLATE"
	echo "stat: $status"
	echo "output: $output"
	[ $status -eq 0 ]
	[[ "$output" == "disp"* ]]
	TEST_STATE["DOM0_TESTVM_1"]="$output"
	echo "arr1: ${TEST_STATE["DOM0_TESTVM_1"]}"

	runSL b_dom0_startDispVM "$UTD_QUBES_DISPVM_TEMPLATE"
	[ $status -eq 0 ]
	echo "output: $output"
	[[ "$output" == "disp"* ]]
	TEST_STATE["DOM0_TESTVM_2"]="$output"
	echo "arr1: ${TEST_STATE["DOM0_TESTVM_1"]}"
	echo "arr2: ${TEST_STATE["DOM0_TESTVM_2"]}"
	[[ "${TEST_STATE["DOM0_TESTVM_2"]}" != "${TEST_STATE["DOM0_TESTVM_1"]}" ]]

	#the function did create a "-" file in the current dir which shouldn't happen:
	[ ! -f ./- ]

	#save state for further tests
	saveBlibTestState
}

@test "b_dom0_getDispVMs" {
	skipIfNoTestVMs

	runSL b_dom0_getDispVMs
	[ "$status" -eq 0 ]
	[ -n "$output" ]

	local line=""
	local testVM1Seen=1
	local testVM2Seen=1
	while IFS= read -r line ; do
		[[ "$line" == "disp"* ]]
		[[ "$line" == "${TEST_STATE["DOM0_TESTVM_1"]}" ]] && testVM1Seen=0
		[[ "$line" == "${TEST_STATE["DOM0_TESTVM_2"]}" ]] && testVM2Seen=0
	done <<< "$output"

	[ $testVM1Seen -eq 0 ]
	[ $testVM2Seen -eq 0 ]

}

@test "b_dom0_isRunning" {
	skipIfNoTestVMs

	runSL b_dom0_isRunning "non-existent-vm"
	echo "output: $output"
	[ $status -ne 0 ]
	[[ "$output" == *"non-existent-vm"* ]]

	runSL b_dom0_isRunning "non existent vm"
	[ $status -ne 0 ]
	[[ "$output" == *"non existent vm"* ]]

	runSL b_dom0_isRunning "${TEST_STATE["DOM0_TESTVM_1"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_isRunning "${TEST_STATE["DOM0_TESTVM_2"]}" "${TEST_STATE["DOM0_TESTVM_1"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_isRunning "${TEST_STATE["DOM0_TESTVM_2"]}" "${TEST_STATE["DOM0_TESTVM_1"]}" "nonex"
	[ $status -ne 0 ]
	[[ "$output" == *"nonex"* ]]
	[[ "$output" != *"${TEST_STATE["DOM0_TESTVM_1"]}"* ]]
	[[ "$output" != *"${TEST_STATE["DOM0_TESTVM_2"]}"* ]]

	#make sure it is shut down
	runSL qvm-shutdown --wait --timeout 10 "$UTD_QUBES_TESTVM"

	runSL b_dom0_isRunning "$UTD_QUBES_TESTVM" "${TEST_STATE["DOM0_TESTVM_2"]}"
	echo "out: $output"
	[ $status -ne 0 ]
	[[ "$output" == *"$UTD_QUBES_TESTVM"* ]]
	[[ "$output" != *"${TEST_STATE["DOM0_TESTVM_1"]}"* ]]
	[[ "$output" != *"${TEST_STATE["DOM0_TESTVM_2"]}"* ]]

	#make sure it wasn't started by the call above
	sleep 10
	runSL b_dom0_isRunning "$UTD_QUBES_TESTVM"
	[ $status -ne 0 ]
	[[ "$output" == *"$UTD_QUBES_TESTVM"* ]]
	[[ "$output" != *"${TEST_STATE["DOM0_TESTVM_1"]}"* ]]
	[[ "$output" != *"${TEST_STATE["DOM0_TESTVM_2"]}"* ]]
}

@test "b_dom0_ensureRunning" {
	skipIfNoTestVMs

	runSL b_dom0_ensureRunning "non-existent-vm" "anotherRandomVM"
	[ $status -ne 0 ]
	[[ "$output" == *"non-existent-vm"* ]]
	[[ "$output" == *"anotherRandomVM"* ]]

	runSL b_dom0_ensureRunning "${TEST_STATE["DOM0_TESTVM_1"]}" "${TEST_STATE["DOM0_TESTVM_2"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#make sure it is shut down
	runSL qvm-shutdown --wait --timeout 10 "$UTD_QUBES_TESTVM"

	runSL b_dom0_isRunning "$UTD_QUBES_TESTVM"
	echo "output: $output"
	[ $status -ne 0 ]
	[[ "$output" == *"$UTD_QUBES_TESTVM"* ]]

	runSL b_dom0_ensureRunning "${TEST_STATE["DOM0_TESTVM_1"]}" "$UTD_QUBES_TESTVM" "${TEST_STATE["DOM0_TESTVM_2"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]
	
	runSL b_dom0_ensureRunning "$UTD_QUBES_TESTVM"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#make sure it is shut down
	runSL qvm-shutdown --wait --timeout 10 "$UTD_QUBES_TESTVM"

	#make sure it remained shut down
	sleep 5
	runSL b_dom0_isRunning "$UTD_QUBES_TESTVM" "${TEST_STATE["DOM0_TESTVM_1"]}" "${TEST_STATE["DOM0_TESTVM_2"]}"
	[ $status -ne 0 ]
	[[ "$output" == *"$UTD_QUBES_TESTVM"* ]]
	[[ "$output" != *"${TEST_STATE["DOM0_TESTVM_1"]}"* ]]
	[[ "$output" != *"${TEST_STATE["DOM0_TESTVM_2"]}"* ]]
}

@test "b_dom0_exists" {
	skipIfNoTestVMs

	runSL b_dom0_exists "nonexisting-vm"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_dom0_exists "${TEST_STATE["DOM0_TESTVM_1"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_exists "${TEST_STATE["DOM0_TESTVM_2"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_exists "$UTD_QUBES_TESTVM"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

function checkEventLoopConnection {
	local name="$2"
	[[ "$name" == "connection-established" ]] && return 22
	echo "name: $name"
	return 33
}

function waitForTestVMStartup {
	local subject="$1"
	local name="$2"
	local info="$3"
	T_EVENT_CNT=$(( $T_EVENT_CNT +1 ))
	[ $T_EVENT_CNT -gt 50 ] && return 66
	[[ "$subject" == "$UTD_QUBES_TESTVM" ]] && [[ "$name" == "domain-start" ]] && [[ "$info" == *"start_guid"* ]] && return 12
	return 0
}

@test "b_dom0_enterEventLoop" {
	skipIfNoTestVMs

	runSL funcTimeout 5 b_dom0_enterEventLoop "checkEventLoopConnection"
	[ $status -eq 22 ]
	[ -z "$output" ]

	#make sure it is shut down
	runSL b_dom0_isRunning "$UTD_QUBES_TESTVM"
	[ $status -ne 0 ]

	#enter event loop in background
	{ set +e ; funcTimeout 60 b_dom0_enterEventLoop "waitForTestVMStartup" ; } &
	local pid=$!

	#start
	runSL b_dom0_ensureRunning "$UTD_QUBES_TESTVM"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#check whether we saw a respective event
	local ret=0
	wait "$pid" || ret=$?
	echo "process ret: $ret"
	[ $ret -eq 12 ]

	#make sure there's no leftover process after the last event
	#processes can take a few ms to terminate gracefully though
	sleep 0.1
	local out=
	out="$(ps aux | grep "qwatch")"
	echo "leftover process check (should be one line):"
	echo "$out"
	out="$(echo "$out" | wc -l)"
	[[ "$out" == "1" ]]
}

@test "b_dom0_qvmRun" {
	skipIfNoTestVMs 

	echo "hello from stdin" | { runSL b_dom0_qvmRun "${TEST_STATE["DOM0_TESTVM_1"]}" 'cat - ; echo "hello from dispvm" ; [ 1 -eq 1 ]'
	[ $status -eq 0 ]
	[[ "$output" == "hello from dispvm" ]]
	}

	echo "hello from stdin" | { runSL b_dom0_qvmRun --stdin "${TEST_STATE["DOM0_TESTVM_1"]}" 'cat - ; echo "hello from dispvm" ; [ 1 -eq 1 ]'
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "hello from stdin"$'\n'"hello from dispvm" ]]
	}

	echo "hello from stdin" | { runSL b_dom0_qvmRun "${TEST_STATE["DOM0_TESTVM_1"]}" 'cat - ; echo "hello from dispvm" ; exit 122'
	echo "$output"
	[ $status -eq 122 ]
	[[ "$output" == "hello from dispvm" ]]
	}

	echo "hello from stdin" | { runSL b_dom0_qvmRun "non-existing-vm" 'cat - ; echo "hello from dispvm" ; exit 122'
	[ $status -ne 0 ]
	[[ "$output" != *"hello"* ]]
	[ -n "$output" ]
	}

	#pass binary data via stdin/out
	echo "hello from stdin" | gzip | { runSL b_dom0_qvmRun --stdin "${TEST_STATE["DOM0_TESTVM_1"]}" 'zcat'
	[ $status -eq 0 ]
	[[ "$output" == "hello from stdin" ]]
	}

	local out=""
	out="$(echo "hello from stdin" | b_dom0_qvmRun --stdin "${TEST_STATE["DOM0_TESTVM_1"]}" 'gzip -f' | zcat)"
	[ $? -eq 0 ]
	[[ "$out" == "hello from stdin" ]]

	#make sure it is shut down
	runSL qvm-shutdown --wait --timeout 10 "$UTD_QUBES_TESTVM"
	[ $status -eq 0 ]

	echo "hello from stdin" | { runSL b_dom0_qvmRun "$UTD_QUBES_TESTVM" 'cat - ; echo "hello from dispvm" ; exit 0'
	[ $status -ne 0 ]
	[[ "$output" != *"hello"* ]]
	[ -n "$output" ]
	}

	#make sure it remained shut down
	sleep 5
	runSL b_dom0_isRunning "$UTD_QUBES_TESTVM"
	[ $status -ne 0 ]

	#with -a
	echo "hello from stdin" | { runSL b_dom0_qvmRun -a --stdin "$UTD_QUBES_TESTVM" 'cat - ; echo "hello from dispvm" ; exit 0'
	[ $status -eq 0 ]
	[[ "$output" == "hello from stdin"$'\n'"hello from dispvm" ]]
	}

	#test stderr output
	local tmpfile="$(mktemp)"
	local out=""
	out="$(b_dom0_qvmRun "$UTD_QUBES_TESTVM" 'echo "stdout here" ; >&2 echo "hello from stderr"' 2> "$tmpfile")"
	[[ "$out" == "stdout here" ]]
	[[ "$(cat "$tmpfile")" == "hello from stderr" ]]

	out="$(b_dom0_qvmRun --stdin "$UTD_QUBES_TESTVM" 'echo "stdout here" ; >&2 echo "hello from stderr"' 2> "$tmpfile" < /dev/null)"
	[[ "$out" == "stdout here" ]]
	[[ "$(cat "$tmpfile")" == "hello from stderr" ]]

	#cleanup
	rm -f "$tmpfile"
}

#testExecIn [function name] [execFile1 as file or string] [execFile2 as file or string] [isFile]
function testExecIn {
	local func="$1"
	local execFile1="$2"
	local execFile2="$3"
	local isFile=${4:-0}

	runSL $func "non-existing-vm" "$execFile2"
	[ $status -ne 0 ]
	echo "out: $output"
	[[ "$output" != *"hello"* ]]
	[[ "$output" == *"Failed to execute qvm-run"* ]]

	if [ $isFile -eq 0 ] ; then
		runSL $func "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/nonexistingfile"
		[ $status -ne 0 ]
		[[ "$output" != *"hello"* ]]
		[ -n "$output" ]
		[[ "$output" == *"doesn't seem to exist"* ]]
	fi

	runSL $func "${TEST_STATE["DOM0_TESTVM_1"]}" "$execFile1"
	echo "out: $output"
	[ $status -eq 101 ]
	[[ "$output" == "hello world!"$'\n'"func called" ]]

	runSL $func "${TEST_STATE["DOM0_TESTVM_2"]}" "$execFile2"
	[ $status -eq 0 ]
	[[ "$output" == "hello world!"$'\n'"func called" ]]

	runSL $func "${TEST_STATE["DOM0_TESTVM_1"]}" "$execFile2" "nonexistinguser"
	[ $status -ne 0 ]
	[[ "$output" != *"hello"* ]]
	[ -n "$output" ]

	#make sure it is shut down
	runSL qvm-shutdown --wait --timeout 10 "$UTD_QUBES_TESTVM"
	[ $status -eq 0 ]

	runSL $func "$UTD_QUBES_TESTVM" "$execFile2"
	[ $status -ne 0 ]
	[[ "$output" != *"hello"* ]]
	[ -n "$output" ]

	#make sure it remained shut down
	sleep 5
	runSL b_dom0_isRunning "$UTD_QUBES_TESTVM"
	[ $status -ne 0 ]
}

@test "b_dom0_execIn" {
	skipIfNoTestVMs 

	local execFile1="$(getDom0Fixture "execFile1")"
	local execFile2="$(getDom0Fixture "execFile2")"

	testExecIn "b_dom0_execIn" "$execFile1" "$execFile2"
}

@test "b_dom0_execStrIn" {
	skipIfNoTestVMs 

	local execFile1="$(getDom0Fixture "execFile1")"
	local execFile1Str="$(cat "$execFile1")"
	local execFile2="$(getDom0Fixture "execFile2")"
	local execFile2Str="$(cat "$execFile2")"

	testExecIn "b_dom0_execStrIn" "$execFile1Str" "$execFile2Str" 1
}

#testFunc01 [param 1/return value] [param 2]
function testFunc01 {
	echo "testFunc01:"
	local p1="$1"
	local p2="$2"
	echo "param2: $p2"
	testFunc01Dep || { echo "testFunc01Dep call failed." ; exit 1 ; }

	b_osid_isQubesVM && echo "In Qubes VM." || "Failed to identify Qubes VM."

	return $p1
}

function testFunc01Dep {
	echo "testFunc01Dep:"
	whoami
}

@test "b_dom0_execFuncIn" {
	skipIfNoTestVMs 

	#the in-depth test is done in the b_generateStandalone test, we just do some basic testing here
	runSL b_dom0_execFuncIn "${TEST_STATE["DOM0_TESTVM_1"]}" "" "testFunc01" 33 "holy moly" - "os/osid" - "testFunc01Dep"
	echo "output: $output"
	[ $status -eq 33 ]
	local eout='testFunc01:
param2: holy moly
testFunc01Dep:
root
In Qubes VM.'
	[[ "$output" == "$eout" ]]

	#some failures
	runSL b_dom0_execFuncIn "${TEST_STATE["DOM0_TESTVM_1"]}" "" "testFunc01-nonexisting" 33 "holy moly" - "os/osid" - "testFunc01Dep"
	[ $status -ne 33 ]
	[ $status -ne 0 ]
	[[ "$output" != *"testFunc01:"* ]]

	runSL b_dom0_execFuncIn "non-existing-vm" "" "testFunc01" 33 "holy moly" - "os/osid" - "testFunc01Dep"
	[ $status -ne 33 ]
	[ $status -ne 0 ]
	[[ "$output" != *"testFunc01:"* ]]
}

@test "b_dom0_parseQvmBlock & b_dom0_getQvmBlockInfo" {
	local qvmBlock1='sys-usb:loop1        /foo/bar/bla.data           test (read-only=no, frontend-dev=xvdi)
sys-us:loop2         /hallo/welt/foo.dd       test2 (read-only=yes, frontend-dev=xvdj)
sys-usb:mmcblk0      ()                         
sys-usb:mmcblk0p1    (mama)                     
mail:dm-0            tada                 
test2:dm-0           desc with spaces                            '
	
	b_import "arr"
	declare -A test1Expected=(
		["max"]=6

		["0_backend"]="sys-usb"
		["0_device id"]="loop1"
		["0_id"]="sys-usb:loop1"
		["0_description"]="/foo/bar/bla.data"
		["0_used by"]="test"
		["0_read-only"]="no"
		["0_frontend-dev"]="xvdi"

		["1_backend"]="sys-us"
		["1_device id"]="loop2"
		["1_id"]="sys-us:loop2"
		["1_description"]="/hallo/welt/foo.dd"
		["1_used by"]="test2"
		["1_read-only"]="yes"
		["1_frontend-dev"]="xvdj"

		["2_backend"]="sys-usb"
		["2_device id"]="mmcblk0"
		["2_id"]="sys-usb:mmcblk0"
		["2_description"]="()"
		["2_used by"]=""
		["2_read-only"]=""
		["2_frontend-dev"]=""

		["3_backend"]="sys-usb"
		["3_device id"]="mmcblk0p1"
		["3_id"]="sys-usb:mmcblk0p1"
		["3_description"]="(mama)"
		["3_used by"]=""
		["3_read-only"]=""
		["3_frontend-dev"]=""

		["4_backend"]="mail"
		["4_device id"]="dm-0"
		["4_id"]="mail:dm-0"
		["4_description"]="tada"
		["4_used by"]=""
		["4_read-only"]=""
		["4_frontend-dev"]=""

		["5_backend"]="test2"
		["5_device id"]="dm-0"
		["5_id"]="test2:dm-0"
		["5_description"]="desc with spaces"
		["5_used by"]=""
		["5_read-only"]=""
		["5_frontend-dev"]=""
		)

	local test1ExpectedSpec="$(declare -p "test1Expected")"
	[ -n "$test1ExpectedSpec" ]

	runSL b_dom0_parseQvmBlock "test1" "$qvmBlock1"
	echo "$output"
	[ $status -eq 0 ]
	[ -n "$output" ]
	eval "$output"
	b_arr_mapsAreEqual "$(declare -p "test1")" "$test1ExpectedSpec"

	#with header
	qvmBlock1="BACKEND:DEVID       DESCRIPTION            USED BY"$'\n'"$qvmBlock1"

	runSL b_dom0_parseQvmBlock "test2" "$qvmBlock1"
	[ $status -eq 0 ]
	[ -n "$output" ]
	eval "$output"
	b_arr_mapsAreEqual "$(declare -p "test2")" "$test1ExpectedSpec"

	#b_dom0_getQvmBlockInfo
	runSL b_dom0_getQvmBlockInfo "$test1ExpectedSpec" "id" "description" "/foo/bar/bla.data"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "sys-usb:loop1" ]]

	runSL b_dom0_getQvmBlockInfo "$test1ExpectedSpec" "description" "backend" "sys-usb" "device id" "mmcblk0p1"
	[ $status -eq 0 ]
	[[ "$output" == "(mama)" ]]

	runSL b_dom0_getQvmBlockInfo "$test1ExpectedSpec" "description" "backend" "sys-usb" "device id" "mmcblk0"
	[ $status -eq 0 ]
	[[ "$output" == "()" ]]

	runSL b_dom0_getQvmBlockInfo "$test1ExpectedSpec" "used by" "backend" "sys-usb" "device id" "mmcblk0"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_getQvmBlockInfo "$test1ExpectedSpec" "frontend-dev" "backend" "sys-usb" "device id" "mmcblk0"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_getQvmBlockInfo "$test1ExpectedSpec" "frontend-dev" "backend" "sys-nonexisting" "device id" "mmcblk0"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_dom0_getQvmBlockInfo "$test1ExpectedSpec" "frontend-dev" "backend" "sys-usb" "device id" "diff"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_dom0_getQvmBlockInfo "$test1ExpectedSpec" "foo" "backend" "sys-usb" "device id" "mmcblk0"
	[ $status -ne 0 ]
	[ -n "$output" ]
	[[ "$output" == *"ERROR"* ]]
}

#testSuccAttachFileInVM [mount point] [rw flag] [umount]
#[mount point]: where to find the file SUCCESS.txt at its root
#[rw flag]: 0 = r/w, 1 = r/o
function testSuccAttachFileInVM {
	local mp="$1"
	local rwFlag="$2"
	local umnt="${3:-1}"
	
	#test read
	local out="$(cat "$mp/SUCCESS.txt" 2> /dev/null)"
	[[ "$out" == "We did it!" ]] || { echo "Failed to read." ; exit 1 ; }

	#test write
	{ echo "foo" > "$mp/WRITE-TEST.txt" ; } 2> /dev/null
	if [ $? -eq 0 ] ; then
		[ $rwFlag -ne 0 ] && echo "Could write even though rw flag was off." && exit 2
	else
		[ $rwFlag -eq 0 ] && echo "Failed to write." && exit 3
	fi

	#test remove
	#NOTE: removing non-existing files will return a 0 exit code
	if [ $rwFlag -eq 0 ] ; then
		rm -f "$mp/WRITE-TEST.txt" || { echo "Failed to remove" ; exit 4 ; }
	else
		rm -f "$mp/SUCCESS.txt" &> /dev/null && echo "Could remove even though rw flag was off." && exit 5
	fi

	#umount if necessary
	if [ $umnt -eq 0 ] ; then
		umount "$mp" || { echo "Failed to umount." ; exit 6 ; }
	fi	

	#all good
	exit 0
}

#testSuccAttachFile [dom0 file] [target VM] [rw flag] [detach]
function testSuccAttachFile {
	local dom0File="$1"
	local vm="$2"
	local rwFlag="${3:-1}"
	local detach="${4:-1}"

	runSL b_dom0_attachFile "$dom0File" "$vm" "$rwFlag"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "/dev/"* ]]
	local dev="$output"

	runSL b_dom0_mountIfNecessary "$vm" "$dev" 
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "/tmp/"* ]]
	local mnt="$output"

	#all as expected in the VM?
	runSL b_dom0_execFuncIn "$vm" "" testSuccAttachFileInVM "$mnt" "$rwFlag" "$detach"
	echo "$output"
	[ $status -eq 0 ]

	if [ $detach -eq 0 ] ; then
		runSL b_dom0_detachDevice "$vm" "$dev"
		[ $status -eq 0 ]
		[ -z "$output" ]
	else
		#save for the detach test
		TEST_STATE["DOM0_DETACH_DEVICE"]="$dev"
		TEST_STATE["DOM0_DETACH_FILE"]="$dom0File"
		saveBlibTestState
	fi
}

@test "b_dom0_createLoopDeviceIfNecessary & b_dom0_mountIfNecessary" {
	skipIfNoTestVMs 

	#some failing tests
	runSL b_dom0_createLoopDeviceIfNecessary "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/non-existing-file"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_createLoopDeviceIfNecessary "non-existing-vm" "/etc/passwd"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_mountIfNecessary "${TEST_STATE["DOM0_TESTVM_1"]}" "/dev/foobar" "/tmp/test"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_mountIfNecessary "non-existing-vm" "/dev/xvdi" "/tmp/test"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#succeeding tests
	local loopFile="$(getDom0Fixture "ext4loop")"
	qvm-copy-to-vm "${TEST_STATE["DOM0_TESTVM_1"]}" "$loopFile"

	local vmUser=""
	vmUser="$(qvm-prefs "${TEST_STATE["DOM0_TESTVM_1"]}" default_user)"
	local loopFileVM="/home/$vmUser/QubesIncoming/dom0/ext4loop"

	runSL b_dom0_createLoopDeviceIfNecessary "${TEST_STATE["DOM0_TESTVM_1"]}" "$loopFileVM"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "/dev/loop"* ]]
	local loopDev="$output"

	runSL b_dom0_createLoopDeviceIfNecessary "${TEST_STATE["DOM0_TESTVM_1"]}" "$loopFileVM"
	echo "out: $output"
	[ $status -eq 0 ]
	[[ "$output" == "$loopDev" ]]

	runSL b_dom0_mountIfNecessary "${TEST_STATE["DOM0_TESTVM_1"]}" "$loopDev"
	echo "out: $output"
	[ $status -eq 0 ]
	[[ "$output" == "/tmp/"* ]]
	local mp="$output"

	runSL b_dom0_mountIfNecessary "${TEST_STATE["DOM0_TESTVM_1"]}" "$loopDev" "/othermp/"
	[ $status -eq 0 ]
	[[ "$output" == "$mp" ]]
	local mp="$output"

	runSL b_dom0_execFuncIn "${TEST_STATE["DOM0_TESTVM_1"]}" "" testSuccAttachFileInVM "$mp" 0 0
	echo "$output"
	[ $status -eq 0 ]

	runSL b_dom0_mountIfNecessary "${TEST_STATE["DOM0_TESTVM_1"]}" "$loopDev" "/othermp/"
	[ $status -eq 0 ]
	[[ "$output" == "/othermp/" ]]
	local mp="$output"

	runSL b_dom0_execFuncIn "${TEST_STATE["DOM0_TESTVM_1"]}" "" testSuccAttachFileInVM "$mp" 0 0
	echo "$output"
	[ $status -eq 0 ]
}

@test "b_dom0_attachFile" {
	skipIfNoTestVMs 
	local loopFile="$(getDom0Fixture "ext4loop")"
	local tmpLoop="$(mktemp)"
	cat "$loopFile" > "$tmpLoop"
	
	#failing tests
	runSL b_dom0_attachFile "$tmpLoop" "non existing vm"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_attachFile "/tmp/nonexisting/$loopFile" "${TEST_STATE["DOM0_TESTVM_1"]}"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#successful tests
	testSuccAttachFile "$tmpLoop" "${TEST_STATE["DOM0_TESTVM_1"]}" 0 0
	testSuccAttachFile "$tmpLoop" "${TEST_STATE["DOM0_TESTVM_1"]}" 1 1

	#a second attach should error out (file is already attached)
	runSL b_dom0_attachFile "$tmpLoop" "${TEST_STATE["DOM0_TESTVM_1"]}" 0
	[ $status -ne 0 ]
	[ -n "$output" ]
}

@test "b_dom0_detachDevice" {
	skipIfNoTestVMs 

	[ -z "${TEST_STATE["DOM0_DETACH_DEVICE"]}" ] && skip "Didn't find a device to test the detach operation with. Maybe the previous test failed?"

	runSL b_dom0_detachDevice "${TEST_STATE["DOM0_TESTVM_1"]}" "/dev/nonexisting"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_detachDevice "non-existing-vm" "${TEST_STATE["DOM0_DETACH_DEVICE"]}"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_detachDevice "${TEST_STATE["DOM0_TESTVM_1"]}" "${TEST_STATE["DOM0_DETACH_DEVICE"]}"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#cleanup
	[[ "${TEST_STATE["DOM0_DETACH_FILE"]}" == "/tmp/"* ]] && rm -f "${TEST_STATE["DOM0_DETACH_FILE"]}"
	unset TEST_STATE["DOM0_DETACH_FILE"]
	unset TEST_STATE["DOM0_DETACH_DEVICE"]
}

@test "b_dom0_isMountedIn" {
	skipIfNoTestVMs

	runSL b_dom0_isMountedIn "${TEST_STATE["DOM0_TESTVM_1"]}" "/notmounted/"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_dom0_isMountedIn "nonexisting-vm" "/dev/xvdb"
	echo "out: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#in Qubes /dev/xvdb tends to be mounted at /rw/
	runSL b_dom0_isMountedIn "${TEST_STATE["DOM0_TESTVM_1"]}" "/dev/xvdb"
	echo "out: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

#createFileAfter [vm] [seconds] [file]
function createFileAfter {
	local vm="$1"
	local seconds="$2"
	local file="$3"

	sleep $seconds
	b_dom0_qvmRun "$vm" "touch \"$file\""
}

@test "b_dom0_waitForFileIn" {
	skipIfNoTestVMs

	runSL b_dom0_waitForFileIn "non-existing-vm" "/tmp/foobar"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#just a single hopefully successful test, the remaining ones are already done in fs.bats
	local tfile="$(mktemp -u)"
	startTimer
	createFileAfter "${TEST_STATE["DOM0_TESTVM_1"]}" 2 "$tfile" 3>&- &
	[ $(endTimer) -le 1 ]
	runSL b_dom0_waitForFileIn "${TEST_STATE["DOM0_TESTVM_1"]}" "$tfile" 4
	[ $(endTimer) -le 3 ]
	[ $status -eq 0 ]
	[ -z "$output" ]
}

#crossAttachTest [test vm 1 file] [mount point] [rw flag]
function crossAttachTest {
	local tFile="$1"
	local mp="$2"
	local rwFlag="$3"

	runSL b_dom0_crossAttachFile "${TEST_STATE["DOM0_TESTVM_1"]}" "$tFile" "${TEST_STATE["DOM0_TESTVM_2"]}" "$rwFlag"
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "/dev/"* ]]
	local dev="$output"

	runSL b_dom0_mountIfNecessary "${TEST_STATE["DOM0_TESTVM_2"]}" "$dev" "$mp"
	[ $status -eq 0 ]
	[[ "$output" == "$mp" ]]

	runSL b_dom0_execFuncIn "${TEST_STATE["DOM0_TESTVM_2"]}" "" testSuccAttachFileInVM "$mp" "$rwFlag"
	echo "$output"
	[ $status -eq 0 ]
}

@test "b_dom0_crossAttachDevice & b_dom0_crossAttachFile" {
	skipIfNoTestVMs 
	#b_dom0_crossAttachFile currently uses b_dom0_crossAttachDevice, so we only need to test the first one

	runSL b_dom0_crossAttachFile "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/nonexistingfile" "${TEST_STATE["DOM0_TESTVM_2"]}"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_crossAttachFile "nonexisting-vm" "/etc/passwd" "${TEST_STATE["DOM0_TESTVM_2"]}"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_crossAttachFile "${TEST_STATE["DOM0_TESTVM_1"]}" "/etc/passwd" "nonexisting-vm"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_crossAttachFile "${TEST_STATE["DOM0_TESTVM_1"]}" "/etc/" "${TEST_STATE["DOM0_TESTVM_2"]}"
	[ $status -ne 0 ]
	[ -n "$output" ]

	local loopFile="$(getDom0Fixture "ext4loop")"
	local tFolder="$(mktemp -d)"
	local tFolderName="$(basename "$tFolder")"
	[ -d "$tFolder" ]

	cp "$loopFile" "$tFolder/1"
	cp "$loopFile" "$tFolder/2"

	qvm-copy-to-vm "${TEST_STATE["DOM0_TESTVM_1"]}" "$tFolder"
	rm -rf "$tFolder"

	local vmUser=""
	vmUser="$(qvm-prefs "${TEST_STATE["DOM0_TESTVM_1"]}" default_user)"
	local vmInc="/home/$vmUser/QubesIncoming/dom0/$tFolderName"

	crossAttachTest "$vmInc/1" "/mnt/testca1" 0
	crossAttachTest "$vmInc/2" "/mnt/testca2" 1
}

#assertkMd5 [vm] [file] [md5]
function assertMd5 {
	local vm="$1"
	local file="$2"
	local ref="$3"

	runSL b_dom0_qvmRun "$vm" "md5sum \"$file\" | cut -f1 -d' '"
	[ $status -eq 0 ]
	echo "MD5: $output"
	echo "ref: $ref"
	[[ "$output" == "$ref" ]]
}

@test "b_dom0_copy" {
	skipIfNoTestVMs 

	local testFile="$(getDom0Fixture "ext4loop")"
	local md5TestFile="$(md5sum "$testFile" | cut -f1 -d' ')"
	[ -n "$md5TestFile" ]
	local targetVMPath="/tmp/DOM0_COPY_TEST/ext4loop"

	runSL b_dom0_copy "$testFile" "non-existing-vm" "/tmp/DOM0_COPY_TEST"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_copy "/tmp/nonexisting-file" "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/DOM0_COPY_TEST"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_copy "$testFile" "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/DOM0_COPY_TEST"
	echo "out1: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" "$md5TestFile"

	runSL b_dom0_copy "$testFile" "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/DOM0_COPY_TEST" 0
	echo "out2: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" "$md5TestFile"

	runSL b_dom0_copy "$testFile" "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/DOM0_COPY_TEST" 1
	echo "out3: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" "$md5TestFile"

	#files - full path
	targetVMPath="/tmp/DOM0_COPY_TEST2/foo"
	runSL b_dom0_copy "$testFile" "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" 1 1
	echo "out4: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" "$md5TestFile"

	runSL b_dom0_copy "$testFile" "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" 0 1
	echo "out5: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" "$md5TestFile"

	#directory copy
	local testDir="$(mktemp -d)"
	local testDirName="${testDir##*/}"
	[ -d "$testDir" ]
	cp "$testFile" "$testDir"
	local targetVMPath="/home/$testDirName/ext4loop"

	runSL b_dom0_copy "$testDir" "${TEST_STATE["DOM0_TESTVM_1"]}" "/home"
	echo "out4: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" "$md5TestFile"

	runSL b_dom0_copy "$testDir" "${TEST_STATE["DOM0_TESTVM_1"]}" "/home" 0
	echo "out5: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" "$md5TestFile"

	runSL b_dom0_copy "$testDir" "${TEST_STATE["DOM0_TESTVM_1"]}" "/home" 1
	echo "out6: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" "$md5TestFile"

	#make sure /home does still exist
	local user="$(qvm-prefs "${TEST_STATE["DOM0_TESTVM_1"]}" "default_user")"
	[ -n "$user" ]
	runSL b_dom0_qvmRun "${TEST_STATE["DOM0_TESTVM_1"]}" "[ -d \"/home\" ] && [ -d \"/home/$user\" ]"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#directories - full path
	local targetVMPath="/tmp/test_dir"

	runSL b_dom0_copy "$testDir" "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" 1 1
	echo "out7: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath/ext4loop" "$md5TestFile"

	runSL b_dom0_copy "$testDir" "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath" 0 1
	echo "out8: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_1"]}" "$targetVMPath/ext4loop" "$md5TestFile"
}

#testSuccCrossCopy [source file or dir] [target dir] [target file path to check md5] [md5] [parent dir]
function testSuccCrossCopy {
	local source="$1"
	local target="$2"
	local checkFile="$3"
	local checkMd5="$4"
	local parentDir=${5:-0}

	runSL b_dom0_crossCopy "${TEST_STATE["DOM0_TESTVM_1"]}" "$source" "${TEST_STATE["DOM0_TESTVM_2"]}" "$target" 1 $parentDir
	echo "out: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_2"]}" "$checkFile" "$checkMd5"

	runSL b_dom0_crossCopy "${TEST_STATE["DOM0_TESTVM_1"]}" "$source" "${TEST_STATE["DOM0_TESTVM_2"]}" "$target" 1 $parentDir
	echo "out: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_2"]}" "$checkFile" "$checkMd5"

	runSL b_dom0_crossCopy "${TEST_STATE["DOM0_TESTVM_1"]}" "$source" "${TEST_STATE["DOM0_TESTVM_2"]}" "$target" 0 $parentDir
	echo "out: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	assertMd5 "${TEST_STATE["DOM0_TESTVM_2"]}" "$checkFile" "$checkMd5"
}

@test "b_dom0_crossCopy" {
	skipIfNoTestVMs 
	local tfile="/etc/passwd"
	local tfileName="passwd"

	#failing tests
	runSL b_dom0_crossCopy "${TEST_STATE["DOM0_TESTVM_1"]}" "$tfile" "nonexisting-vm" "/tmp/holymoly/"
	echo "out: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_crossCopy "nonexisting-vm" "$tfile" "${TEST_STATE["DOM0_TESTVM_2"]}" "/tmp/holymoly/"
	echo "out: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_crossCopy "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/nonexistingfile" "${TEST_STATE["DOM0_TESTVM_2"]}" "/tmp/holymoly/"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_crossCopy "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/nonexistingfile" "${TEST_STATE["DOM0_TESTVM_2"]}" "/tmp/holymoly/" 1 1
	[ $status -ne 0 ]
	[ -n "$output" ]

	#successful tests with files
	local cmd="md5sum \"$tfile\" | cut -d' ' -f1"
	runSL b_dom0_qvmRun "${TEST_STATE["DOM0_TESTVM_1"]}" "$cmd"
	[ $status -eq 0 ]
	[ -n "$output" ]
	local tfileMd5="$output"
	testSuccCrossCopy "$tfile" "/tmp/holymoly/" "/tmp/holymoly/$tfileName" "$tfileMd5"
	#without trailing slash:
	testSuccCrossCopy "$tfile" "/tmp/holymoly2" "/tmp/holymoly2/$tfileName" "$tfileMd5"
	#full path variant:
	local fullPath="/tmp/holymoly3/foobar"
	testSuccCrossCopy "$tfile" "$fullPath" "$fullPath" "$tfileMd5" 1

	#successful tests with directories
	local tfolder="$(mktemp -u -d)"
	local tfolderName="$(basename "$tfolder")"
	local cmd="mkdir \"$tfolder\" || exit 11 ; cp /etc/passwd \"$tfolder\""
	runSL b_dom0_qvmRun "${TEST_STATE["DOM0_TESTVM_1"]}" "$cmd"
	[ $status -eq 0 ]
	[ -z "$output" ]
	testSuccCrossCopy "$tfolder" "/tmp/foldertest/" "/tmp/foldertest/$tfolderName/$tfileName" "$tfileMd5"
	#full path variants (with & without trailing slah):
	local fullPath="/tmp/foldertest/the_new_name"
	testSuccCrossCopy "$tfolder" "$fullPath" "$fullPath/$tfileName" "$tfileMd5" 1
	local fullPath="/tmp/foldertest/the_new_name2"
	testSuccCrossCopy "$tfolder" "$fullPath/" "$fullPath/$tfileName" "$tfileMd5" 1
}

@test "b_dom0_openCrypt & b_dom0_closeCrypt" {
	skipIfNoTestVMs 

	local luksFile="$(getDom0Fixture "luksloop")"
	local luksKey="$(getDom0Fixture "lukskey")"

	qvm-copy-to-vm "${TEST_STATE["DOM0_TESTVM_1"]}" "$luksFile"
	qvm-copy-to-vm "${TEST_STATE["DOM0_TESTVM_1"]}" "$luksKey"

	local vmUser=""
	vmUser="$(qvm-prefs "${TEST_STATE["DOM0_TESTVM_1"]}" default_user)"

	local luksFileVM="/home/$vmUser/QubesIncoming/dom0/luksloop"
	local luksKeyVM="/home/$vmUser/QubesIncoming/dom0/lukskey"

	runSL b_dom0_createLoopDeviceIfNecessary "${TEST_STATE["DOM0_TESTVM_1"]}" "$luksFileVM"
	[ $status -eq 0 ]
	[ -n "$output" ]
	[[ "$output" == "/dev/loop"* ]]
	local loopDevVM="$output"

	runSL b_dom0_openCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "/tmp/nonexistingfile" "luksdev" "" "" "$luksKeyVM"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_openCrypt "non-existing-vm" "$loopDevVM" "luksdev" "" "" "$luksKeyVM"
	echo "out: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_qvmRun "${TEST_STATE["DOM0_TESTVM_1"]}" "[ -e \"/dev/mapper/luksdev01\" ]"
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_dom0_openCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "$loopDevVM" "luksdev01" "" "" "$luksKeyVM"
	echo "out: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_qvmRun "${TEST_STATE["DOM0_TESTVM_1"]}" "[ -e /dev/mapper/luksdev01 ]"
	echo "out: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_closeCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "luksdev01" "/nonexistingmnt/"
	echo "out: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_closeCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "luksdev01"
	echo "out: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_closeCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "luksdev01"
	echo "out: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_closeCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "luksdev01-another-nonexisting"
	echo "out: $output"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_openCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "$loopDevVM" "luksdev02" "" "/mntl02" "$luksKeyVM"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_execFuncIn "${TEST_STATE["DOM0_TESTVM_1"]}" "" testSuccAttachFileInVM "/mntl02" 0
	echo "out: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_closeCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "luksdev02" "/mntl02"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_openCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "$loopDevVM" "luksdev03" 1 "/mntl03" "$luksKeyVM"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_execFuncIn "${TEST_STATE["DOM0_TESTVM_1"]}" "" testSuccAttachFileInVM "/mntl03" 1
	echo "out: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_closeCrypt "${TEST_STATE["DOM0_TESTVM_1"]}" "luksdev03" "/mntl03"
	[ $status -eq 0 ]
	[ -z "$output" ]
}

#testDiskAttach [target VM] [rw flag]
function testDiskAttach {
	local targetVM="$1"
	local rwFlag="$2"
	#NOTE: we can only use a persistent VM as source (disposable VMs have no private.img disk file)

	runSL b_dom0_ensureRunning "$targetVM"
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_dom0_attachVMDisk "$UTD_QUBES_TESTVM_PERSISTENT" "$targetVM" "$UTD_QUBES_DOM0_WD" "$rwFlag"
	echo "out attach: $output"
	[ $status -eq 0 ]
	[[ "$output" == "/dev/"* ]]
	local dev="$output"

	runSL b_dom0_mountIfNecessary "$targetVM" "$dev"
	echo "out mount: $output"
	[ $status -eq 0 ]
	[ -n "$output" ]
	local mp="$output"

	#this also tests whether SUCCESS.txt created below can be accessed
	runSL b_dom0_execFuncIn "$targetVM" "" testSuccAttachFileInVM "$mp" "$rwFlag"
	echo "testSuccAttachFileInVM: $output"
	[ $status -eq 0 ]
	[ -z "$output" ]
	
	#for detach
	runSL qvm-shutdown --wait --timeout 10 "$targetVM"
	[ $status -eq 0 ]

	#further cleanup
	[ -d "$UTD_QUBES_DOM0_WD" ]
	rm -rf "$UTD_QUBES_DOM0_WD"
}

@test "b_dom0_attachVMDisk" {
	skipIfNoTestVMs

	#NOTE: this test should be the last if possible as the 2 involved VMs should be shut down afterwards (or you'll runSL into strange issues)

	[ -z "$UTD_QUBES_DOM0_WD" ] && skip "You didn't set UTD_QUBES_DOM0_WD in $USER_DATA_FILE. Please do that in order to run this test."
	[ -e "$UTD_QUBES_DOM0_WD" ] && skip "The file or folder $UTD_QUBES_DOM0_WD appears to exist. Thus backing off... (this test will otherwise remove it and all of its content)"

	runSL b_dom0_attachVMDisk "non-existing-vm" "${TEST_STATE["DOM0_TESTVM_1"]}" "$UTD_QUBES_DOM0_WD"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_dom0_attachVMDisk "$UTD_QUBES_TESTVM_PERSISTENT" "non-existing-vm" "$UTD_QUBES_DOM0_WD"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#create test file
	local tfile="/rw/SUCCESS.txt"
	runSL b_dom0_ensureRunning "$UTD_QUBES_TESTVM_PERSISTENT"
	[ $status -eq 0 ]
	[ -z "$output" ]
	runSL b_dom0_qvmRun "$UTD_QUBES_TESTVM_PERSISTENT" "echo \"We did it!\" > \"$tfile\""
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL qvm-shutdown --wait --timeout 10 "$UTD_QUBES_TESTVM_PERSISTENT"
	[ $status -eq 0 ]

	#tests: attach from $UTD_QUBES_TESTVM_PERSISTENT --> $UTD_QUBES_TESTVM
	testDiskAttach "$UTD_QUBES_TESTVM" 0
	testDiskAttach "$UTD_QUBES_TESTVM" 1
}

@test "dom0 clean" {
	if [ -n "${TEST_STATE["DOM0_TESTVM_1"]}" ] ; then
		runSL qvm-shutdown "${TEST_STATE["DOM0_TESTVM_1"]}"
		unset TEST_STATE["DOM0_TESTVM_1"]
	fi

	if [ -n "${TEST_STATE["DOM0_TESTVM_2"]}" ] ; then
		runSL qvm-shutdown "${TEST_STATE["DOM0_TESTVM_2"]}"
		unset TEST_STATE["DOM0_TESTVM_2"]
	fi

	if [ -n "$UTD_QUBES_TESTVM" ] ; then
		runSL qvm-shutdown "$UTD_QUBES_TESTVM"
	fi

	if [ -n "$UTD_QUBES_TESTVM_PERSISTENT" ] ; then
		runSL qvm-shutdown "$UTD_QUBES_TESTVM_PERSISTENT"
	fi

	#update state
	saveBlibTestState
}
