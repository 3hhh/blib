#!/usr/bin/env bats
# 
#+Bats tests for the args module.
#+
#+Copyright (C) 2019  David Hobach  LGPLv3
#+0.4

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

function runSuccParseNoChecks {
	runSL b_args_parse "$@"
	echo "$output"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#validate the state change in our context
	b_args_parse "$@"
}

function runSuccParse {
	runSuccParseNoChecks "$@"

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

@test "setters & getters" {
	testGetterSetter "b_args_setOptionParamSeparator" "SEPARATOR"
}

@test "b_args_init" {
	#invalid inits
	runSL b_args_init 0 "-a"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_args_init 0 "-a" 1 "foo"
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_args_init 0 "-aa" 1
	[ $status -ne 0 ]
	[ -n "$output" ]

	runSL b_args_init 0 "--a!a" 1
	[ $status -ne 0 ]
	[ -n "$output" ]

	#valid inits
	runSL b_args_init 0
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_init 1
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_init 1 "-a" 2
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_init 1 "-a" 2 "-b" 0
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_init 0 "-a" 2 "-b" 0 "--holymoly" 0 "--fo-o" 1
	[ $status -eq 0 ]
	[ -z "$output" ]

	#re-inits should have no impact on the internal state
	b_args_init 0 "-a" 2 "-b" 0 "--holymoly" 0 "--foo" 1
	runSL b_args_parse "-b"
	b_args_init 0 "-a" 1 "--holymoly" 0
	declare -p B_ARGS
	declare -p B_ARGS_OPTS
	declare -p BLIB_ARGS_OPTCNT
	echo "a"
	[ "${#B_ARGS[@]}" -eq 0 ]
	echo "b"
	[ "${#B_ARGS_OPTS[@]}" -eq 0 ]
	echo "c"
	[ "${#BLIB_ARGS_OPTCNT[@]}" -eq 2 ]
	echo "d"
	[ ${BLIB_ARGS_OPTCNT["-a"]} -eq 1 ]
	echo "e"
	[ ${BLIB_ARGS_OPTCNT["--holymoly"]} -eq 0 ]
	echo "f"
	[ -z "${BLIB_ARGS_OPTCNT["--foo"]}" ]
}

@test "b_args_parse & b_args_assertOptions" {
	b_args_init "" "-a" 2 "-b" 0 "--holymoly" 0 "--foo" 1

	runSL b_args_assertOptions
	[ $status -eq 0 ]
	[ -z "$output" ]

	runSL b_args_assertOptions "--test"
	[ $status -eq 0 ]
	[ -z "$output" ]

	#failing (missing option argument)
	runSL b_args_parse "the first arg" --foo
	[ $status -ne 0 ]
	[ -n "$output" ]

	#successful
	T_ARGS=("param 1" " spacy par  " "some text" "final")
	T_ARGS_OPTS=(["--foo_0"]="blibla" ["-a_0"]="asdPar 1 	 asdPar2" ["--another_0"]="" ["-b_0"]="")
	runSuccParse "param 1" "-b" " spacy par  " --foo blibla -a "asdPar 1 " " asdPar2" "some text" --another final

	runSL b_args_assertOptions
	[ $status -ne 0 ]
	[[ "$output" == *"-b"* ]]
	[[ "$output" == *"--foo"* ]]
	[[ "$output" == *"-a"* ]]
	[[ "$output" == *"--another"* ]]
	[[ "$output" != *"some"* ]]

	runSL b_args_assertOptions "--another"
	echo "$output"
	[ $status -ne 0 ]
	[[ "$output" == *"-b"* ]]
	[[ "$output" == *"--foo"* ]]
	[[ "$output" == *"-a"* ]]
	[[ "$output" != *"--another"* ]]
	[[ "$output" != *"some"* ]]

	runSL b_args_assertOptions "--another" "-b"
	[ $status -ne 0 ]
	[[ "$output" != *"-b"* ]]
	[[ "$output" == *"--foo"* ]]
	[[ "$output" == *"-a"* ]]
	[[ "$output" != *"--another"* ]]
	[[ "$output" != *"some"* ]]

	runSL b_args_assertOptions "--another" "--foo" "-a" -b
	[ $status -eq 0 ]
	[ -z "$output" ]

	#empty param
	T_ARGS=("param 1" "" " spacy par  " "some text" "final")
	T_ARGS_OPTS=(["--foo_0"]="blibla" ["-a_0"]="asdPar 1 	 asdPar2" ["--another_0"]="" ["-b_0"]="")
	runSuccParse "param 1" "" "-b" " spacy par  " --foo blibla -a "asdPar 1 " " asdPar2" "some text" --another final

	#no params
	T_ARGS=()
	T_ARGS_OPTS=()
	runSuccParse

	#--
	T_ARGS=("param 1" "" " spacy par  " "--foo" "blibla" "-a" "asdPar 1 " " asdPar2" "some text" "--another" "final")
	T_ARGS_OPTS=(["-b_0"]="")
	runSuccParse "param 1" "" "-b" " spacy par  " -- --foo blibla -a "asdPar 1 " " asdPar2" "some text" --another final

	#option with --param
	T_ARGS=("param 1" "" " spacy par  " "some text" "final")
	T_ARGS_OPTS=(["--foo_0"]="--foopar" ["-a_0"]="asdPar 1 	 asdPar2" ["--another_0"]="" ["-b_0"]="")
	runSuccParse "param 1" "" "-b" " spacy par  " --foo --foopar -a "asdPar 1 " " asdPar2" "some text" --another final

	#multiple parameters
	T_ARGS=("param 1" " spacy par  " "some text" "final")
	T_ARGS_OPTS=(["--foo_0"]="foopar" ["--foo_1"]="another" ["-a_0"]="asdPar 1 	 asdPar2" ["--another_0"]="" ["--another_1"]="" ["-b_0"]="")
	runSuccParse "param 1" "-b" " spacy par  " --foo "foopar" --foo "another" -a "asdPar 1 " " asdPar2" "some text" --another final --another

	#combined parameters, no option arguments
	b_args_init 1 "-a" 0 "-b" 0 "-c" 2 "-d" 1
	T_ARGS=("param 1" "" "final")
	T_ARGS_OPTS=(["-a_0"]="" ["-b_0"]="")
	runSuccParse "param 1" "" -ba "final"

	#combined parameters, option arguments for a single option
	T_ARGS=("param 1" "" "final")
	T_ARGS_OPTS=(["-a_0"]="" ["-b_0"]="" ["-c_0"]="arg1	arg2")
	runSuccParse "param 1" "" -ac "arg1" "arg2" "final" -b

	#combined parameters, option arguments for a multiple options (should fail)
	runSL b_args_parse "param 1" "" -dc "arg1" "arg2" "final" -b
	echo "$output"
	[ $status -ne 0 ]
	[[ "$output" == *"ERROR"* ]]
	[[ "$output" == *"Ambiguous"* ]]

	#enforce
	b_args_init 1 "-d" 2 "-b" 0 "--holymoly" 0 "--foo" 1
	runSL b_args_parse "param 1" "" "-b" " spacy par  " --foo --foopar -d "asdPar 1 " " asdPar2" "some text" --another final
	echo "$output"
	[ $status -ne 0 ]
	[[ "$output" == *"--another"* ]]
	[[ "$output" != *"-b"* ]]
	[[ "$output" != *"--foo"* ]]
	[[ "$output" != *"-d"* ]]
	[[ "$output" != *"--holymoly"* ]]
	[[ "$output" != *"some"* ]]
	T_ARGS=("param 1" "" " spacy par  " "some text" "final")
	T_ARGS_OPTS=(["--foo_0"]="--foopar" ["-d_0"]="asdPar 1 	 asdPar2" ["--holymoly_0"]="" ["-b_0"]="")
	runSuccParse "param 1" "" "-b" " spacy par  " --foo --foopar -d "asdPar 1 " " asdPar2" "some text" final "--holymoly"
}

@test "b_args_get[Option], b_args_get[Option]Int & b_args_get[Option]Count" {
	b_args_init "" "-a" 2 "-b" 0 "--foo" 1
	runSuccParseNoChecks "param 1" "-b" " spacy par  " --foo "foopar" --foo "another" --foo "" -a "asdPar 1 " "2" "" 456 --another final --another

	local fb="fallback"

	#b_args_get[Option]Count
	runSL b_args_getCount
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "5" ]]

	runSL b_args_getOptionCount
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "7" ]]

	#b_args_get[Int]
	runSL b_args_get -1 "$fb"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getInt -1 "$fb"
	echo "$output"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_get 0 "$fb"
	[ $status -eq 0 ]
	[[ "$output" == "param 1" ]]

	runSL b_args_getInt 0 "$fb"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_get 2 "$fb"
	[ $status -eq 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getInt 2 "$fb"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_get 3 "$fb"
	[ $status -eq 0 ]
	[[ "$output" == "456" ]]

	runSL b_args_getInt 3 "$fb"
	[ $status -eq 0 ]
	[[ "$output" == "456" ]]

	runSL b_args_get 4 "$fb"
	[ $status -eq 0 ]
	[[ "$output" == "final" ]]

	runSL b_args_getInt 4 "$fb"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_get 5 "$fb"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getInt 5 "$fb"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	#b_args_getOption[Int]
	runSL b_args_getOption "-b" "$fb"
	[ $status -eq 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOptionInt "-b" "$fb"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "-b" "$fb" 0
	[ $status -eq 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "-b" "$fb" 0 0
	echo "$output"
	[ $status -eq 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "-b" "$fb" 0 1
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "-b" "$fb" 1
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "--nonexisting" "$fb"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "--foo" "$fb"
	[ $status -eq 0 ]
	[[ "$output" == "foopar" ]]

	runSL b_args_getOption "--foo" "$fb" "" 0
	[ $status -eq 0 ]
	[[ "$output" == "foopar" ]]

	runSL b_args_getOption "--foo" "$fb" "" 1
	echo "$output"
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "--foo" "$fb" 1
	[ $status -eq 0 ]
	[[ "$output" == "another" ]]

	runSL b_args_getOption "--foo" "$fb" 2
	[ $status -eq 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "--foo" "$fb" 3
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "-a" "$fb"
	[ $status -eq 0 ]
	[[ "$output" == "asdPar 1 	2" ]]

	runSL b_args_getOption "-a" "$fb" "" 0
	[ $status -eq 0 ]
	[[ "$output" == "asdPar 1 " ]]

	runSL b_args_getOption "-a" "$fb" 0 0
	[ $status -eq 0 ]
	[[ "$output" == "asdPar 1 " ]]

	runSL b_args_getOptionInt "-a" "$fb" 0 0
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOption "-a" "$fb" 1 0
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]

	runSL b_args_getOptionInt "-a" "$fb" 0 1
	[ $status -eq 0 ]
	[[ "$output" == "2" ]]

	runSL b_args_getOption "-a" "$fb" 0 2
	[ $status -ne 0 ]
	[[ "$output" == "$fb" ]]
}
