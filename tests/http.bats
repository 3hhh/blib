#!/usr/bin/env bats
# 
#+Bats tests for the http module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "http"
}

@test "b_http_rawUrlEncode & Decode" {
	local raw1='äölälüpsadlüpldüpdsadsad  HOLY! shit'
	local enc1='%C3%A4%C3%B6l%C3%A4l%C3%BCpsadl%C3%BCpld%C3%BCpdsadsad%20%20HOLY%21%20shit'
	local raw2='?hallo!we&%lt"my friendZ$?0'
	local enc2='%3Fhallo%21we%26%25lt%22my%20friendZ%24%3F0'

	runB b_http_rawUrlEncode ""
	[ $status -eq 0 ]
	[ -z "$output" ]
echo 1
	runB b_http_rawUrlDecode ""
	[ $status -eq 0 ]
	[ -z "$output" ]
echo 1

	runB b_http_rawUrlEncode "$raw1"
echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "$enc1" ]]
echo 1

	runB b_http_rawUrlEncode "$raw2"
	[ $status -eq 0 ]
	[[ "$output" == "$enc2" ]]
echo 1

	runB b_http_rawUrlEncode "$enc1"
	[ $status -eq 0 ]
	local encoded="$output"
echo 1

	runB b_http_rawUrlDecode "$encoded"
	[ $status -eq 0 ]
	[[ "$output" == "$enc1" ]]
echo 1

	runB b_http_rawUrlDecode "$enc1"
	[ $status -eq 0 ]
	[[ "$output" == "$raw1" ]]
echo 1

	runB b_http_rawUrlDecode "$enc2"
	[ $status -eq 0 ]
	[[ "$output" == "$raw2" ]]
}

@test "b_http_getOnlineStatus" {
	skipIfNoUserData

	runB b_http_getOnlineStatus
	[ -z "$output" ]
	if [[ "$UTD_ONLINE" == "no" ]] ; then
		[ $status -ne 0 ]
	else
		[ $status -eq 0 ]
	fi

	B_HTTP_CHECKURLS=( "https://nonexisting.nonexisting" )

	runB b_http_getOnlineStatus
	[ -z "$output" ]
	[ $status -eq 2 ]
}
