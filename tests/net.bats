#!/usr/bin/env bats
# 
#+Bats tests for the net module.
#+
#+Copyright (C) 2020  David Hobach  LGPLv3
#+0.1

#load common test code
load test_common

function setup {
	loadBlib
	b_import "net"
}

@test "b_net_getDNSStatus" {
	skipIfNoUserData

	runSL b_net_getDNSStatus
	[ -z "$output" ]
	if [[ "$UTD_ONLINE" == "no" ]] ; then
		[ $status -eq 2 ]
	else
		[ $status -eq 0 ]
	fi

	runSL b_net_getDNSStatus "" "random"
	[ -z "$output" ]
	if [[ "$UTD_ONLINE" == "no" ]] ; then
		[ $status -eq 2 ]
	else
		[ $status -eq 0 ]
	fi

	B_NET_CHECKHOSTS=( "nonexisting.nonexisting" )

	runSL b_net_getDNSStatus 2
	[ -z "$output" ]
	if [[ "$UTD_ONLINE" == "no" ]] ; then
		[ $status -eq 2 ]
	else
		[ $status -eq 1 ]
	fi

	B_RC=99
	runSL b_net_getDNSStatus 1 "nonexistingserver"
	[[ "$output" == *"ERROR"* ]]
	[ $status -eq 99 ]
}
