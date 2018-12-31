#!/usr/bin/env bats
# 
#+Bats tests for the blib installer.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load user data if available
USER_DATA_FILE="$BATS_TEST_DIRNAME/tests/user_test_data.bash"
USER_DATA_AVAILABLE=1
load "$USER_DATA_FILE" &> /dev/null && USER_DATA_AVAILABLE=0

#path to the installer
INSTALLER="$BATS_TEST_DIRNAME/installer"

#default installation directory
DEFAULT_INSTALL_DIR="/usr/lib"

#to become root
SUDO_PREFIX="su root -c"
command -v sudo &> /dev/null && SUDO_PREFIX="sudo $SUDO_PREFIX"

function skipIfRootUnavailable {
	[[ "$UTD_PW_FREE_USER" != "root" ]] && skip "UTD_PW_FREE_USER would have to be specified as root in the user test data file $USER_DATA_FILE for this test to work." || return 0
}

function skipIfInstalled {
	[ -e "/usr/bin/blib" ] && skip "It appears that blib is installed on your system. Since this test may cause changes to your current installation, it is skipped." || return 0
}

#ensureInstalled [install dir]
function ensureInstalled {
	local installDir="${1:-$DEFAULT_INSTALL_DIR}"
	[ -f "/usr/bin/blib" ]
	[ -d "$installDir/blib" ]
	[ -d "$installDir" ]
	[ -d "/usr/bin/" ]
	if command -v pandoc &> /dev/null ; then
		[ -f "/usr/share/man/man3/blib.3" ]
	fi

	#attempt to read a few files
	cat "/usr/bin/blib" > /dev/null
	cat "$installDir/blib/lib/cdoc" > /dev/null
	
	#make sure the test marker is there (otherwise we shouldn't be operating on this folder)
	cat "$installDir/blib/doc/BATS_TEST_MARKER" > /dev/null

	#attempt write
	local tFile="$installDir/blib/doc/TEST_WRITE_FILE"
	touch "$tFile"
	rm "$tFile"
}

#ensureRemoved [install dir]
function ensureRemoved {
	local installDir="${1:-$DEFAULT_INSTALL_DIR}"

	[ ! -e "/usr/bin/blib" ]
	[ ! -e "$installDir/blib" ]
	[ ! -e "/usr/share/man/man3/blib.3" ]
	[ -d "$installDir" ]
	[ -d "/usr/bin/" ]
	[ -d "/usr/share/man/man3" ]
}

#testInstall [expected status] [install dir]
function testInstall {
	local eStatus=$1
	local installDir="${2:-$DEFAULT_INSTALL_DIR}"
	echo "Installation: $installDir"

	run $SUDO_PREFIX "$INSTALLER install \"$installDir\""
	echo "$output"
	[ $status -eq $eStatus ]
	[ -n "$output" ]

	if [ $eStatus -eq 0 ] ; then
		ensureInstalled "$installDir" || exit 1
		
		#set a marker indicating that this installation was completed from this test
		touch "$installDir/blib/doc/BATS_TEST_MARKER"
	fi
}

#testUninstall [expected status] [install dir]
function testUninstall {
	local eStatus=$1
	local installDir="${2:-$DEFAULT_INSTALL_DIR}"
	echo "Removal: $installDir"

	run $SUDO_PREFIX "$INSTALLER uninstall \"$installDir\""
	echo "$output"
	[ $status -eq $eStatus ]
	[ -n "$output" ]
	
	if [ $eStatus -eq 0 ] ; then
		ensureRemoved "$installDir" || exit 1
	fi
}

@test "install" {
	skipIfRootUnavailable
	skipIfInstalled

	local tmpInst="$(mktemp -d)"
	[ -n "$tmpInst" ]

	ensureRemoved
	ensureRemoved "$tmpInst"

	testInstall 0 "$tmpInst"
	testUninstall 0 "$tmpInst"
	testInstall 0 "$tmpInst/"
	testUninstall 0 "$tmpInst/"

	#default install test
	testInstall 0
	testUninstall 0
	testInstall 0

	#cleanup
	rm -rf "$tmpInst"
}

@test "blib tests" {
	ensureInstalled

	#NOTE: it is recommended to run this test as the user who runs blib
	
	#it was installed from the previous test
	#the whole point of this test is to run the blib tests with the installed version as that one might have access issues, the installation partially failed or whatever
	cd ~
	run blib test
	echo "$output"
	[ $status -eq 0 ]
	[ -n "$output" ]
}

@test "uninstall" {
	skipIfRootUnavailable

	#Note: the following line also checks whether the installation was created by the test above (test marker)
	ensureInstalled

	#failing
	testUninstall 1 "/tmp/nonexisting"
	testUninstall 1 "/tmp/nonexisting/"
	
	ensureInstalled

	#hopefully working, was installed above
	testUninstall 0
}
