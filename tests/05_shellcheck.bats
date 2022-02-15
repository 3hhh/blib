#!/usr/bin/env bats
# 
#+Bats shellcheck tests for all blib modules.
#+
#+Copyright (C) 2022  David Hobach  LGPLv3
#+0.5

#load common test code
load test_common

function setup {
  loadBlib
}

#execShellCheck [path 1] ... [path n]
function execShellcheck {
  local path=
  local ret=0

  for path in "$@" ; do
    if [ -f "$path" ] ; then
      echo "########################################################################################################"
      echo "Checking ${path}..."
      shellcheck -s "bash" -S "warning" "$path" || ret=$?
    elif [ -d "$path" ] ; then
      local file=
      for file in "$path"/* ; do
        execShellcheck "$file" || ret=$?
      done
    else
      #ignore
      :
    fi
  done
  
  return $ret
}

@test "shellcheck" {
  skipIfCommandMissing "shellcheck"

  paths=(
    "$B_LIB_DIR/blib"
    "$B_LIB_DIR/installer"
    "$B_LIB_DIR/util/bkeys"
    "$B_LIB_DIR/util/blib-cdoc"
    "$B_LIB_DIR/lib"
    )
  runSL execShellcheck "${paths[@]}"
  echo "$output"
  [ $status -eq 0 ]
}
