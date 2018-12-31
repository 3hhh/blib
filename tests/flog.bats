#!/usr/bin/env bats
# 
#+Bats tests for the flog library.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "flog"
}

#getLogReference [name]
#[name]: name of the log reference to obtain
#returns: full path to the respective file
function getLogReference {
	echo "${FIXTURES_DIR}/flog/${1}"
}

#getSample01Severity [index]
#returns: a deterministic severity for the given index
function getSample01Severity {
local i=$1
local c=$(( i % 17 ))
	case $c in
		0)
			echo "${B_FLOG_SEV["emergency"]}"
			;;
		1)
			echo "${B_FLOG_SEV["alert"]}"
			;;
		2)
			echo "${B_FLOG_SEV["critical"]}"
			;;
		3)
			echo "${B_FLOG_SEV["crit"]}"
			;;
		4)
			echo "${B_FLOG_SEV["error"]}"
			;;
		5)
			echo "${B_FLOG_SEV["err"]}"
			;;
		6)
			echo "${B_FLOG_SEV["warning"]}"
			;;
		7)
			echo "${B_FLOG_SEV["warn"]}"
			;;
		8)
			echo "${B_FLOG_SEV["notice"]}"
			;;
		9)
			echo "${B_FLOG_SEV["informational"]}"
			;;
		10)
			echo "${B_FLOG_SEV["info"]}"
			;;
		11)
			echo "${B_FLOG_SEV["debug"]}"
			;;
		12)
			echo "TEXT SEVERITY"
			;;
		*)
			echo ""
			;;
	esac
return 0
}

#createSample01 [start index] [end index] [expected status]
#Creates a sample log with messages starting with [start index] and ending with [end index] (exclusive).
function createSample01 {
	local s=$1
	local e=$2
	local eStatus=${3:-0}
	
	for (( i=$s;i<$e;i++)) ; do
		local sev="$(getSample01Severity $i)"
		runB b_flog_log "Msg $i " "$sev"
		[ $status -eq $eStatus ]
		if [ $status -eq 0 ] ; then
			[ -z "$output" ]
		else
			[ -n "$output" ]
		fi
	done
}

#stripTimestamps [file]
#Strip the leading timestamps from the given file and return a copy of it with those removed.
function stripTimestamps {
	local file="$1"
	local out="$(mktemp)"
	local re='^[^ ]+ [^ ]+ [^ ]+ (.*)$'
	local line=""

	while IFS= read -r line ; do
		[[ "$line" =~ $re ]] && echo "${BASH_REMATCH[1]}" >> "$out"
	done < "$file"

	echo "$out"
}

#diffLog [created file] [reference file name]
#[created file]: path to a log file created via a test (/dev/stdout or /dev/stderr doesn't really work)
#[reference file name]: name of the log file found in the reference folder to compare the created file to
#Compares the newly created file with its reference whilst ignoring timestamps.
#returns: a non-zero exit code if there are differences
function diffLog {
	local createdFile="$1"
	local deleteCreated=1
		if [[ "$createdFile" == "/dev/stdout" || "$createdFile" == "/dev/stderr" ]] ; then
			#bats will redirect stdout and stderr to a file --> we can read from that and [ -f ] will return true
			[ -f "$createdFile" ]
			deleteCreated=0
			local origFile="$(readlink -f "$createdFile")"
			createdFile="$(mktemp)"
			cp -f "$origFile" "$createdFile"
		fi
	local referenceFile="$(getLogReference "$2")"
	local createdFileNoTimestamps="$(stripTimestamps "$createdFile")"
	echo "created file: $createdFile"
	echo "reference file: $referenceFile"
	echo "created file no timestamps: $createdFileNoTimestamps"
	diff "$createdFileNoTimestamps" "$referenceFile" || return 1
	rm -f "$createdFileNoTimestamps"

	[ $deleteCreated -eq 0 ] && rm -f "$createdFile"
	return 0
}

function testHeader {
echo "test header"
}

#closeLog [log file name]
#[log file name]: path to the log file or stdout/err
function closeLog {
	local file="$1"
	b_flog_close
	set +e
	[[ "$file" != "/dev/"* ]] && rm -f "$file"
	set -e
	return 0
}

#runValid01Tests [log file name] [check diff]
#[log file name]: path to the log file (/dev/stdout or err doesn't really work)
function runValid01Tests {
	local logFile="$1"
	local checkDiff="${2:-0}"

	#default header
	#NOTE: we cannot use runB on b_flog_init as that would do the init in some subprocess (i.e. we couldn't use follow-up commands)
	b_flog_init "$logFile"
	#if it fails, it'll automatically fail this test due to -e
	
	createSample01 1 80
	[ $checkDiff -eq 0 ] && diffLog "$logFile" "ref01.log"

	#different header, same file (should append)
	b_flog_init "$logFile" "b_flog_headerDateSeverity"

	createSample01 80 150
	[ $checkDiff -eq 0 ] && diffLog "$logFile" "ref02.log"
	
	#different header, nonexistent file
	closeLog "$logFile"
	b_flog_init "$logFile" "b_flog_headerDateScriptSeverity"

	createSample01 1 100
	[ $checkDiff -eq 0 ] && diffLog "$logFile" "ref03.log"

	#invalid = default header
	closeLog "$logFile"
	b_flog_init "$logFile" "non_existent_header_func"
	createSample01 1 80 1
	[ $checkDiff -eq 0 ] && diffLog "$logFile" "ref04.log"
	
	#own header
	closeLog "$logFile"
	b_flog_init "$logFile" "testHeader"
	createSample01 1 80
	[ $checkDiff -eq 0 ] && diff "$logFile" "$(getLogReference "ref05.log")"
	
	#log file reduction
	closeLog "$logFile"
	b_flog_init "$logFile" "b_flog_defaultHeader" 100
	createSample01 1 80
	[ $checkDiff -eq 0 ] && diffLog "$logFile" "ref01.log"
	createSample01 80 120
	[ $checkDiff -eq 0 ] && diffLog "$logFile" "ref06.log"
	#should go to 119, reduce to 80, then add a note and add the remaining 19 lines --> end at msg 139 (99 lines)
	createSample01 120 140
	[ $checkDiff -eq 0 ] && diffLog "$logFile" "ref07.log"
	createSample01 140 212
	[ $checkDiff -eq 0 ] && diffLog "$logFile" "ref08.log"
	
	#no limit for log file reduction
	closeLog "$logFile"
	b_flog_init "$logFile" "b_flog_defaultHeader" -1
	createSample01 1 80
	[ $checkDiff -eq 0 ] && diffLog "$logFile" "ref01.log"

	#some cleanup
	closeLog "$logFile"
}

@test "valid file logging" {
	#testing stdout & err diffs doesn't make much sense atm as bats redirects them to a file itself and that file contains both outputs incl. the ones from our test --> hard to compare against anything --> runB without diff
	runValid01Tests "$(mktemp)"
}

@test "valid stdout logging" {
	runValid01Tests "/dev/stdout" 1
}

@test "valid stderr logging" {
	runValid01Tests "/dev/stderr" 1
}

@test "log without init" {
	runB b_flog_log "foo log entry"
	[ $status -ne 0 ]
	[ -n "$output" ]
}

@test "b_flog_close" {
	#without init
	runB b_flog_close
	[ $status -eq 0 ]
	[ -z "$output" ]

	#with init
	b_flog_init
	b_flog_close
	[ $status -eq 0 ]
	[ -z "$output" ]
}

@test "getters and setters" {
	b_flog_setDateFormat "%s"

	runB b_flog_getDateFormat
	[ $status -eq 0 ]
	[[ "$output" == "%s" ]]

	b_flog_setHeaderFunction "holy moly"

	runB b_flog_getHeaderFunction
	[ $status -eq 0 ]
	[[ "$output" == "holy moly" ]]

	b_flog_setLogReductionLinesApprox 200

	runB b_flog_getLogReductionLinesLowerBound
	[ $status -eq 0 ]
	[[ "$output" == "160" ]]
	
	runB b_flog_getLogReductionLinesUpperBound
	[ $status -eq 0 ]
	[[ "$output" == "240" ]]

	b_flog_setLogReductionLinesLowerBound 12
	b_flog_setLogReductionLinesUpperBound -1

	runB b_flog_getLogReductionLinesLowerBound
	[ $status -eq 0 ]
	[[ "$output" == "12" ]]

	runB b_flog_getLogReductionLinesUpperBound
	[ $status -eq 0 ]
	[[ "$output" == "-1" ]]

	b_flog_setLogReductionLinesLowerBound -20

	runB b_flog_getLogReductionLinesLowerBound
	[ $status -eq 0 ]
	[[ "$output" == "-20" ]]

	runB b_flog_setLogReductionLinesApprox -1
	[ $status -eq 0 ]
	[ -z "$output" ]

	#cleanup
	b_flog_close
}

#createError [msg]
function createError {
B_ERR="$1" ; B_E
}

@test "b_flog_errorHandler" {
	b_setErrorHandler "b_flog_errorHandler"
	echo 1

	#without init
	runB createError "error! fatal!"
	echo 2
	[ $status -ne 0 ]
	[ -n "$output" ]
	[[ "$output" != *"error!"* ]]

	#with init
	local logFile="$(mktemp)"
	b_flog_init "$logFile" "b_flog_headerDateSeverity"
	runB createError "error! fatal!"
	echo 3
	echo "STAT: $status"
	echo "OUT: $output"
	[ $status -ne 0 ]
	[ -z "$output" ]
	diffLog "$logFile" "refe01.log"
	closeLog "$logFile"

	#with different sev
	b_flog_init "$logFile" "b_flog_headerDateSeverity"
	b_setErrorHandler "b_flog_errorHandler 0 1 1 0 1 ${B_FLOG_SEV["emergency"]}"
	runB createError "super fatal error"
	echo 4
	[ $status -ne 0 ]
	[ -z "$output" ]
	diffLog "$logFile" "refe02.log"

	#maybe TODO: test some more options

	#cleanup
	echo 5
	closeLog "$logFile"
	b_setErrorHandler "b_default_errorHandler"
}
