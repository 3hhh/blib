#!/usr/bin/env bats
# 
#+Bats tests for the args module.
#+
#+Copyright (C) 2019  David Hobach  LGPLv3
#+0.3

#load common test code
load test_common

function setup {
	loadBlib
	b_import "args"
	b_import "arr"
}

#expected arguments and options for runSuccParse
declare -ga T_ARGS
declare -gA T_ARGS_OPTS

function runSuccParse {
	runSL b_args_parse "$@"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#validate the state change in our context
	b_args_parse "$@"

	echo "opt check"
	declare -p T_ARGS_OPTS
	declare -p B_ARGS_OPTS
	runSL b_arr_mapsAreEqual "$(declare -p T_ARGS_OPTS)" "$(declare -p B_ARGS_OPTS)"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	echo "regular arg check"
	declare -p T_ARGS
	declare -p B_ARGS
	diff <(printf "%s\n" "${T_ARGS[@]}") <(printf "%s\n" "${B_ARGS[@]}")
}

@test "b_args_init" {
	#invalid inits
	runSL b_args_init 0 "-asd"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_args_init 0 "-asd" 1 "foo"
	[ $status -ne 0 ]
	[ -n "$output" ]

	#valid inits
	runSL b_args_init 0
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_init 1
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_init 1 "-asd" 2
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_init 1 "-asd" 2 "-b" 0
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_init 0 "-asd" 2 "-b" 0 "--holymoly" 0 "--foo" 1
	[ $status -eq 0 ]
	[ -z "$output" ]

	#re-inits should have no impact on the internal state
	b_args_init 0 "-asd" 2 "-b" 0 "--holymoly" 0 "--foo" 1
	runSL b_args_parse "-b"
	b_args_init 0 "-asd" 1 "--holymoly" 0
	declare -p B_ARGS
	declare -p B_ARGS_OPTS
	declare -p BLIB_ARGS_OPTCNT
	echo "a"
	[ "${#B_ARGS}" -eq 0 ]
	echo "b"
	[ "${#B_ARGS_OPTS}" -eq 0 ]
	echo "c"
	[ "${#BLIB_ARGS_OPTCNT[@]}" -eq 2 ]
	echo "d"
	[ ${BLIB_ARGS_OPTCNT["-asd"]} -eq 1 ]
	echo "e"
	[ ${BLIB_ARGS_OPTCNT["--holymoly"]} -eq 0 ]
	echo "f"
	[ -z "${BLIB_ARGS_OPTCNT["--foo"]}" ]
}

@test "b_args_parse & b_args_assertOptions" {
	b_args_init "" "-asd" 2 "-b" 0 "--holymoly" 0 "--foo" 1

	runSL b_args_assertOptions
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_assertOptions "--test"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#failing
	runSL b_args_parse "the first arg" --foo
	[ $status -ne 0 ]
	[ -n "$output" ]

	#successful
	T_ARGS=("param 1" " spacy par  " "some text" "final")
	T_ARGS_OPTS=(["--foo"]="blibla" ["-asd"]="asdPar\ 1\  \ asdPar2" ["--another"]="" ["-b"]="")
	runSuccParse "param 1" "-b" " spacy par  " --foo blibla -asd "asdPar 1 " " asdPar2" "some text" --another final

	runSL b_args_assertOptions
	[ $status -ne 0 ]
	[[ "$output" == *"-b"* ]]
	[[ "$output" == *"--foo"* ]]
	[[ "$output" == *"-asd"* ]]
	[[ "$output" == *"--another"* ]]
	[[ "$output" != *"some"* ]]

	runSL b_args_assertOptions "--another"
	[ $status -ne 0 ]
	[[ "$output" == *"-b"* ]]
	[[ "$output" == *"--foo"* ]]
	[[ "$output" == *"-asd"* ]]
	[[ "$output" != *"--another"* ]]
	[[ "$output" != *"some"* ]]

	runSL b_args_assertOptions "--another" "-b"
	[ $status -ne 0 ]
	[[ "$output" != *"-b"* ]]
	[[ "$output" == *"--foo"* ]]
	[[ "$output" == *"-asd"* ]]
	[[ "$output" != *"--another"* ]]
	[[ "$output" != *"some"* ]]

	runSL b_args_assertOptions "--another" "--foo" "-asd" -b
	[ $status -eq 0 ]
	[ -z "$output" ]

	#empty param
	T_ARGS=("param 1" "" " spacy par  " "some text" "final")
	T_ARGS_OPTS=(["--foo"]="blibla" ["-asd"]="asdPar\ 1\  \ asdPar2" ["--another"]="" ["-b"]="")
	runSuccParse "param 1" "" "-b" " spacy par  " --foo blibla -asd "asdPar 1 " " asdPar2" "some text" --another final

	#no params
	T_ARGS=()
	T_ARGS_OPTS=()
	runSuccParse

	#--
	T_ARGS=("param 1" "" " spacy par  " "--foo" "blibla" "-asd" "asdPar 1 " " asdPar2" "some text" "--another" "final")
	T_ARGS_OPTS=(["-b"]="")
	runSuccParse "param 1" "" "-b" " spacy par  " -- --foo blibla -asd "asdPar 1 " " asdPar2" "some text" --another final

	#option with --param
	T_ARGS=("param 1" "" " spacy par  " "some text" "final")
	T_ARGS_OPTS=(["--foo"]="--foopar" ["-asd"]="asdPar\ 1\  \ asdPar2" ["--another"]="" ["-b"]="")
	runSuccParse "param 1" "" "-b" " spacy par  " --foo --foopar -asd "asdPar 1 " " asdPar2" "some text" --another final

	#enforce
	b_args_init 1 "-asd" 2 "-b" 0 "--holymoly" 0 "--foo" 1
	runSL b_args_parse "param 1" "" "-b" " spacy par  " --foo --foopar -asd "asdPar 1 " " asdPar2" "some text" --another final
	[ $status -ne 0 ]
	[[ "$output" == *"--another"* ]]
	[[ "$output" != *"-b"* ]]
	[[ "$output" != *"--foo"* ]]
	[[ "$output" != *"-asd"* ]]
	[[ "$output" != *"--holymoly"* ]]
	[[ "$output" != *"some"* ]]
	T_ARGS=("param 1" "" " spacy par  " "some text" "final")
	T_ARGS_OPTS=(["--foo"]="--foopar" ["-asd"]="asdPar\ 1\  \ asdPar2" ["--holymoly"]="" ["-b"]="")
	runSuccParse "param 1" "" "-b" " spacy par  " --foo --foopar -asd "asdPar 1 " " asdPar2" "some text" final "--holymoly"
}
