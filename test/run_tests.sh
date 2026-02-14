#!/bin/bash

# On GITHUB we call the script with an argument to secure the runner to quit
# when there is an error.
# Locally, we don't need to shut off everything when there is an error.

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
LOGGER_DEF_FILE="logger.vim"

# Fix logger file to be used by runner.vim
cat >"$LOGGER_DEF_FILE" <<'EOF' &&
vim9script

g:logger = g:replica_config.log_filepath
EOF


# Fix .vimrc - make atomic write (overkill to me, but still...)
tmp="$(mktemp "${VIMRC}.XXXX")"

cat >"$tmp" <<'EOF' &&
vim9script

set runtimepath+=..
filetype indent plugin on

g:replica_config = {}
g:replica_config.debug = true
g:replica_config.log_level = 'Error'

g:TestFiles = [
		'test_replica_python.vim',
		'test_replica_julia.vim',
		'test_replica_sh.vim',
    'test_replica_r.vim'
  ]
EOF

mv "$tmp" "$VIMRC"

# Display vimrc content
echo "----- vimrc content ------"
cat $VIMRC
echo ""

echo "----- logger info ------"
cat $LOGGER_DEF_FILE
echo ""

# Build command: this may change depending on the plugin
VIM_CMD=(
    "$VIM_PRG"
    --clean
    -u "$VIMRC"
    -i NONE
    -N
    --not-a-term
		-S "$LOGGER_DEF_FILE"
    -S runner.vim
)

# Execute Vim
"${VIM_CMD[@]}"

# Check that Vim started and that the runner did its job
if [ $? -eq 0 ]; then
		printf 'Vim successfully started.\n\n'
else
		printf "Vim execution failed with exit code %s.\n" "$?"
		exit 1
fi

# Check the test results
cat results.txt
echo "-------------------------------"
if grep -qw FAIL results.txt; then
	echo "ERROR: Some test(s) failed."
	echo
	rm "$VIMRC"
	rm "$LOGGER_DEF_FILE"
	if [ "$GITHUB" -eq 1 ]; then
		rm results.txt
		exit 3
	fi
else
	echo "SUCCESS: All the tests  passed."
	echo
	rm "$VIMRC"
	rm "$LOGGER_DEF_FILE"
	rm results.txt
	exit 0
fi

# kill %- > /dev/null
# vim: shiftwidth=2 softtabstop=2 noexpandtab
