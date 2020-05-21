#!/usr/bin/env bats
# 
#+Bats tests for the hash module.
#+
#+Copyright (C) 2020  David Hobach  LGPLv3
#+0.4

#load common test code
load test_common

function setup {
	loadBlib
	b_import "hash"
}

#testHashFile [algorithm] [expected output]
function testHashFile {
	local algo="$1"
	local expected="$2"

	runSL b_hash_file "$FIXTURES_DIR/hash/test01" "$algo"
	[ $status -eq 0 ]
	[[ "$output" == "$expected" ]]
}

#testHashStr [algorithm] [expected output]
function testHashStr {
	local algo="$1"
	local expected="$2"

	runSL b_hash_str "hello world!" "$algo"
	[ $status -eq 0 ]
	[[ "$output" == "$expected" ]]
}

@test "b_hash_file" {
	runSL b_hash_file "/etc/nonexistingfile"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	runSL b_hash_file "$FIXTURES_DIR/hash/test01" "nonexistingalgo"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	testHashFile "" "c897d1410af8f2c74fba11b1db511e9e"
	testHashFile "md5" "c897d1410af8f2c74fba11b1db511e9e"
	testHashFile "sha1" "f951b101989b2c3b7471710b4e78fc4dbdfa0ca6"
	testHashFile "sha224" "d301812e62eec9b1e68c0b861e62f374e0d77e8365f5ddd6cccc8693"
	testHashFile "sha256" "ecf701f727d9e2d77c4aa49ac6fbbcc997278aca010bddeeb961c10cf54d435a"
	testHashFile "sha384" "ec8d147738b2e4bf6f5c5ac50a9a7593fb1ee2de01474d6f8a6c7fdb7ac945580772a5225a4c7251a7c0697acb7b8405"
	testHashFile "sha512" "f5408390735bf3ef0bb8aaf66eff4f8ca716093d2fec50996b479b3527e5112e3ea3b403e9e62c72155ac1e08a49b476f43ab621e1a5fc2bbb0559d8258a614d"
	testHashFile "crc" "4188851852"
	testHashFile "blake2" "fc13029e8a5ce67ad5a70f0cc659a4b30df9d791b125835e434606c6127ee37ebbc8b216389682ddfa84380789db09f2535d2a9837454414ea3ff00ec0801150"
}

@test "b_hash_str" {
	runSL b_hash_str "hello world!" "nonexistingalgo"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]

	testHashStr "" "c897d1410af8f2c74fba11b1db511e9e"
	testHashStr "md5" "c897d1410af8f2c74fba11b1db511e9e"
	testHashStr "sha1" "f951b101989b2c3b7471710b4e78fc4dbdfa0ca6"
	testHashStr "sha224" "d301812e62eec9b1e68c0b861e62f374e0d77e8365f5ddd6cccc8693"
	testHashStr "sha256" "ecf701f727d9e2d77c4aa49ac6fbbcc997278aca010bddeeb961c10cf54d435a"
	testHashStr "sha384" "ec8d147738b2e4bf6f5c5ac50a9a7593fb1ee2de01474d6f8a6c7fdb7ac945580772a5225a4c7251a7c0697acb7b8405"
	testHashStr "sha512" "f5408390735bf3ef0bb8aaf66eff4f8ca716093d2fec50996b479b3527e5112e3ea3b403e9e62c72155ac1e08a49b476f43ab621e1a5fc2bbb0559d8258a614d"
	testHashStr "crc" "4188851852"
	testHashStr "blake2" "fc13029e8a5ce67ad5a70f0cc659a4b30df9d791b125835e434606c6127ee37ebbc8b216389682ddfa84380789db09f2535d2a9837454414ea3ff00ec0801150"
}
