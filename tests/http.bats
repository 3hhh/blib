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
	local enc1l='%c3%a4%c3%b6l%c3%a4l%c3%bcpsadl%c3%bcpld%c3%bcpdsadsad%20%20HOLY%21%20shit'
	local raw2='?hallo!we&%lt"my friendZ$?0'
	local enc2='%3Fhallo%21we%26%25lt%22my%20friendZ%24%3F0'
	local enc2l='%3fhallo%21we%26%25lt%22my%20friendZ%24%3f0'

	runSL b_http_rawUrlEncode ""
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_http_rawUrlDecode ""
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_http_rawUrlEncode "$raw1"
	[ $status -eq 0 ]
	[[ "$output" == "$enc1" ]] || [[ "$output" == "${enc1//%20/+}" ]] || [[ "$output" == "$enc1l" ]] || [[ "$output" == "${enc1l//%20/+}" ]]

	runSL b_http_rawUrlEncode "$raw2"
	[ $status -eq 0 ]
	[[ "$output" == "$enc2" ]] || [[ "$output" == "${enc2//%20/+}" ]] || [[ "$output" == "$enc2l" ]] || [[ "$output" == "${enc2l//%20/+}" ]]

	runSL b_http_rawUrlEncode "$enc1"
	[ $status -eq 0 ]
	local encoded="$output"

	runSL b_http_rawUrlDecode "$encoded"
	[ $status -eq 0 ]
	[[ "$output" == "$enc1" ]] || [[ "$output" == "${enc1//%20/+}" ]] || [[ "$output" == "${enc1//+/%20}" ]] || [[ "$output" == "$enc1l" ]] || [[ "$output" == "${enc1l//%20/+}" ]] || [[ "$output" == "${enc1l//+/%20}" ]]

	runSL b_http_rawUrlDecode "$enc1"
	[ $status -eq 0 ]
	[[ "$output" == "$raw1" ]]

	runSL b_http_rawUrlDecode "$enc2"
	[ $status -eq 0 ]
	[[ "$output" == "$raw2" ]]
}

@test "b_http_getOnlineStatus" {
	skipIfNoUserData

	runSL b_http_getOnlineStatus
	[ -z "$output" ]
	if [[ "$UTD_ONLINE" == "no" ]] ; then
		[ $status -ne 0 ]
	else
		[ $status -eq 0 ]
	fi

	B_HTTP_CHECKURLS=( "https://nonexisting.nonexisting" )

	runSL b_http_getOnlineStatus
	[ -z "$output" ]
	[ $status -eq 2 ]
}

@test "b_http_testProxy" {
	#NOTE: we currently only test failing scenarios as we don't have a working proxy

	runSL b_http_testProxy 'nonexisting.proxytld'
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_http_testProxy 'nonexisting.proxytld' 1 1
	[ $status -ne 0 ]
	[ -z "$output" ]

	runSL b_http_testProxy 'nonexisting.proxytld' 0 1
	[ $status -ne 0 ]
	[ -z "$output" ]
}
