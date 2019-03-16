#!/usr/bin/env bats
# 
#+Bats tests for the os/osid module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.5

#load common test code
load ../test_common

function setup {
	loadBlib
	b_import "os/osid"
}

#checkOS [function name] [user data variable] [target OS regex]
function checkOS {
	local func="$1"
	local udata="$2"
	local targetOSRegex="$3"

	skipIfNoUserData
	
	local eStatus=1
	[[ "$udata" =~ $targetOSRegex ]] && eStatus=0

	runSL $func
	[ $status -eq $eStatus ]
	[ -z "$output" ]
}

@test "b_osid_isDebian" {
	checkOS "b_osid_isDebian" "$UTD_OS" "^debian$"
}

@test "b_osid_isOpenSuse" {
	checkOS "b_osid_isOpenSuse" "$UTD_OS" "^opensuse$"
}

@test "b_osid_isDebianLike" {
	checkOS "b_osid_isDebianLike" "$UTD_OS" "^(debian|ubuntu)$"
}

@test "b_osid_isFedora" {
	checkOS "b_osid_isFedora" "$UTD_OS" "^fedora$"
}

@test "b_osid_isCentOS" {
	checkOS "b_osid_isCentOS" "$UTD_OS" "^centos$"
}

@test "b_osid_isFedoraLike" {
	#Qubes OS is also "Fedora like" as it uses yum in both dom0 and its client VMs
	if [[ "$UTD_QUBES" =~ ^(vm|dom0)$ ]] ; then
		checkOS "b_osid_isFedoraLike" "$UTD_OS" "^${UTD_OS}$"
	else
		checkOS "b_osid_isFedoraLike" "$UTD_OS" "^(fedora|red hat)$"
	fi
}

@test "b_osid_isRedHat" {
	checkOS "b_osid_isRedHat" "$UTD_OS" "^red hat$"
}

@test "b_osid_isUbuntu" {
	checkOS "b_osid_isUbuntu" "$UTD_OS" "^ubuntu$"
}

@test "b_osid_isQubesDom0" {
	checkOS "b_osid_isQubesDom0" "$UTD_QUBES" "^dom0$"
}

@test "b_osid_isQubesVM" {
	checkOS "b_osid_isQubesVM" "$UTD_QUBES" "^vm$"
}
