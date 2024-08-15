#!/bin/bash

# Script to run the unit-tests for the vim-replica.vim
# Copied and adapted from Vim LSP plugin

GITHUB=1

# No arguments passed, then no exit
if [ "$#" -eq 0 ]; then
  GITHUB=0
fi

VIM_PRG=${VIM_PRG:=$(which vim)}
if [ -z "$VIM_PRG" ]; then
  echo "ERROR: vim (\$VIM_PRG) is not found in PATH"
  if [ "$GITHUB" -eq 1 ]; then
	exit 1
  fi
fi

# Setup dummy VIMRC file
# OBS: You can also run the following lines in the test file because it is
# source before running the tests anyway. See Vim9-conversion-aid
VIMRC="VIMRC"
echo "set runtimepath+=.." > "$VIMRC"
echo "filetype plugin on" >> "$VIMRC"

# Construct the VIM_CMD with correct variable substitution and quoting
# VIM_CMD="$VIM_PRG -u $VIMRC -U NONE -i NONE --noplugin -N --not-a-term"
VIM_CMD="$VIM_PRG -u $VIMRC -U NONE -i NONE -N --not-a-term"

# Add space separated tests, i.e. "test_replica.vim test_pippo.vim etc"
TESTS="test_replica.vim"

RunTestsInFile() {
  testfile=$1
  echo "Running tests in $testfile"
  # If you want to see the output remove the & from the line below
  eval $VIM_CMD " -c \"vim9cmd g:TestName = '$testfile'\" -S runner.vim"

  if ! [ -f results.txt ]; then
    echo "ERROR: Test results file 'results.txt' is not found."
	if [ "$GITHUB" -eq 1 ]; then
	   rm VIMRC
	   exit 2
	fi
  fi

  cat results.txt

  if grep -qw FAIL results.txt; then
    echo "ERROR: Some test(s) in $testfile failed."
		if [ "$GITHUB" -eq 1 ]; then
			exit 3
		fi
	else
		echo "SUCCESS: All the tests in $testfile passed."
		echo
  fi
}

for testfile in $TESTS
do
  RunTestsInFile $testfile
done

echo "SUCCESS: All the tests passed."
# UBA: uncomment the line below
if [ "$GITHUB" -eq 1 ]; then
  exit 0
fi

rm "$VIMRC"
# kill %- > /dev/null
# vim: shiftwidth=2 softtabstop=2 noexpandtab
