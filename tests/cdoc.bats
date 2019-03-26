#!/usr/bin/env bats
# 
#+Bats tests for the cdoc module.
#+
#+Copyright (C) 2018  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "cdoc"
}

function genFileList {
	local par=
	for par in "$@" ; do
		echo "$FIXTURES_DIR/cdoc/$par"
	done
}

#testGenerateDiff [test files/dirs] [expected output file]
#Test b_cdoc_generate raw output (no pandoc call) with the given test files. The output must match the expected output file.
function testGenerateDiff {
	local inFiles="$1"
	local expected="$2"

	local tmpOut="$(mktemp -u)"

	echo "INFILES: $inFiles"
	echo "expected out: $expected"
	runSL b_cdoc_generate "$inFiles" "$tmpOut"
	echo "$output"
	echo "TEMP OUTPUT: $tmpOut"
	[ $status -eq 0 ]
	diff "$tmpOut" "$expected"

	#cleanup
	rm "$tmpOut"
}

@test "setters & getters" {
	testGetterSetter "b_cdoc_setDocumentBeginCallback" "testDocBeginCb"
	testGetterSetter "b_cdoc_setDocumentEndCallback" "testDocEndCb"
	testGetterSetter "b_cdoc_setFileFilterCallback" "testFileFilterCb"
	testGetterSetter "b_cdoc_setPostProcessingCallback" "testPostProcCb"
	testGetterSetter "b_cdoc_setExtractionRegex" 'foo regex'
	testGetterSetter "b_cdoc_setSpaceCallback" "foobar"
}

function initWithTestCallbacks {
	b_cdoc_setDocumentBeginCallback "testDocBeginCb"
	b_cdoc_setDocumentEndCallback "testDocEndCb"
	b_cdoc_setFileFilterCallback "testFileFilterCb"
	b_cdoc_setPostProcessingCallback "testPostProcCb"
	b_cdoc_setSpaceCallback "testSpaceCb"
}

@test "b_cdoc_generate" {
	initWithTestCallbacks

	testGenerateDiff "$(genFileList "test01")" "$(genFileList "test01_expected")"
	echo "1"
	testGenerateDiff "$(genFileList "test02")" "$(genFileList "test02_expected")"
	echo "2"
	testGenerateDiff "$(genFileList "test02" "test01")" "$(genFileList "test03_expected")"
	echo "2.1"
	testGenerateDiff "$(genFileList "test01" "test02")" "$(genFileList "test03_expected")"
	echo "2.2"
	testGenerateDiff "$(genFileList "test03")" "$(genFileList "test03_expected")"
	echo "3"
	testGenerateDiff "$(genFileList "test02" "test03" "test01")" "$(genFileList "test04_expected")"
	echo "4"
}


#pandocTest [out file] [out format]
function pandocTest {
	skipIfNoPandoc

	local outFile="$1"
	local outFormat="$2"

	initWithTestCallbacks

	runSL b_cdoc_generate "$(genFileList "test02" "test01")" "$outFile" "$outFormat"
	echo "$output"
	echo "OUTPUT FILE: $outFile"
	[ $status -eq 0 ]
	[ -f "$outFile" ]

	#cleanup
	rm -f "$outFile"
}

@test "b_cdoc_generate - tex output" {
	pandocTest "$(mktemp -u)" "latex"
}

@test "b_cdoc_generate - html output" {
	pandocTest "$(mktemp -u)" "html5"
}

@test "b_cdoc_generate - pdf output" {
	pandocTest "$(mktemp -u).pdf" "pandoc"
}

##### some callback functions to test with
function testFileFilterCb {
	#make sure the params are passed
	[ $# -ne 1 ] && exit 1

	echo "$1" | sort
}

function testDocBeginCb {
	#make sure the params are passed
	[ $# -ne 2 ] && exit 1

	echo "#DOC HEADER"
}

function testSpaceCb {
	#make sure the params are passed
	[ $# -ne 4 ] && exit 1

	echo ""
}

function testDocEndCb {
	#make sure the params are passed
	[ $# -ne 2 ] && exit 1

	echo "DOC FOOTER LINE 1"
	echo "DOC FOOTER LINE 2"
}

#testPostProcCb [processed input] [input file] [document output format]
function testPostProcCb {
	#make sure the params are passed
	[ $# -ne 3 ] && exit 1

	local input="$1"
	local inFile="$2"

	echo ""
	echo "##$(basename "$inFile")"
	echo ""
	echo "$input"
}
