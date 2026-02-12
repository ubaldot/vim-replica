vim9script

# Test for the vim-replica plugin
# Copied and adjusted from Vim distribution

# OBS! Sometimes these tests fail!

# Uncomment for debug
import "../plugin/replica.vim"
import "../lib/ftcommands_mappings.vim" as ftcm

import "./common.vim"
var WaitForAssert = common.WaitForAssert

def Generate_testfile(lines: list<string>, src_name: string)
  writefile(lines, src_name)
enddef

def Cleanup_testfile(src_name: string)
  delete(src_name)
enddef

def WaitForPrompt(expected_prompt: string)
  const buf_nr = term_list()[0]
  var counter = 0
  const max_count = 50 * 2  # 20*(2*50ms) = 2 seconds max
  var line = ''

  while counter < max_count
    line = LastNonEmptyLine(buf_nr)
    if line =~# expected_prompt
      # Expected prompt appeared, return immediately
      break
    endif
    sleep 50m
    counter += 1
  endwhile

  # Timeout reached, fail with actual last line
  if counter == max_count
    throw $"Prompt not found: {expected_prompt}, got: {line} after waiting {counter * 50} ms"
  endif
enddef

# When you read a terminal buffer with getbufline(buf_nr, 1, '$'), you get
# something like: ['bla bla', 'foo foo', '', 'bar bar', 'In [2]: ', '', '',
# '', '', '', '', '', '', '', '', '', '', '', '', '', '', ]
def LastNonEmptyLine(buf_nr: number): string
  var lines = getbufline(buf_nr, 1, '$')
  for l in reverse(lines)
    if trim(l) !=# ''
      return l
    endif
  endfor
  return ''
enddef

# Tests start here
def g:Test_sh_basic()
  v:errors = []
  v:errmsg = ''
  messages clear

  if exepath('bash')->empty()
    throw "Skipped: 'bash' executable is not found in $PATH"
  endif

  v:errors = []
  messages clear

  const src_name = 'testfile.sh'
  const code_lines =<< trim END
_VIM_USER_VARS=()

# ─────────────────────────────
# Portable types

FOO="Hello"
_VIM_USER_VARS+=("FOO")

BAR=42
_VIM_USER_VARS+=("BAR")

ARR=("apple" "banana" "cherry")
_VIM_USER_VARS+=("ARR")

# %% ─────────────────────────────
# Shell-specific types

if [ -n "${BASH_VERSION:-}" ]; then
    # Bash associative array
    declare -A MAP=(
        [name]="bash"
        [type]="assoc"
    )
    _VIM_USER_VARS+=("MAP")

elif [ -n "${ZSH_VERSION:-}" ]; then
    # Zsh associative array
    typeset -A MAP
    MAP=(
        name zsh
        type assoc
    )
    _VIM_USER_VARS+=("MAP")
fi
END

  Generate_testfile(code_lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_name")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  const expected_prompt = 'vim_replica> '
  WaitForPrompt(expected_prompt)

  var bufnr = term_list()[0]
  var lastline = LastNonEmptyLine(bufnr)
  assert_match(expected_prompt, lastline)

  # # ReplicaSendCell
  cursor(1, 1)
  var expected_lines = [15, 34]

  for line in expected_lines
    exe "ReplicaSendCell"
    WaitForPrompt(expected_prompt)
    # Check that in the editor you end up in the correct line
    assert_equal(line, line('.'))
  endfor

  # # ReplicaSendLine
  cursor(6, 1)
  expected_lines = [7, 8]

  for line in expected_lines
    exe "ReplicaSendLine"
    WaitForPrompt(expected_prompt)
    # Check that in the editor you end up in the correct line
    assert_equal(line, line('.'))
  endfor

  # # Double Toggle
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(1, winnr('$')))
  WaitForAssert(() => assert_true(bufexists('BASH')))
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))
  WaitForAssert(() => assert_true(bufexists('BASH')))

  # Remove cells
  exe "ReplicaRemoveCells"
  WaitForAssert(() => assert_equal(search('# %%', 'cnw'), 0))

  # Restart repl
  exe "ReplicaConsoleRestart"
  WaitForPrompt(expected_prompt)
  bufnr = term_list()[0]
  lastline = LastNonEmptyLine(bufnr)
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_match(expected_prompt, lastline))

  # ReplicaSendFile
  exe "ReplicaSendFile"
  WaitForPrompt(expected_prompt)
  lastline = LastNonEmptyLine(bufnr)
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_match(expected_prompt, lastline))

  # Shutoff
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('BASH')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  # ---- teardown tests ----
  if !empty(v:errors) || !empty(v:errmsg)
    echom "Test failed!"
  else
    echom "Test passed!"
  endif

  :%bw!
  Cleanup_testfile(src_name)
enddef


def g:Test_sh_variable_explorer_basic()
  messages clear
  v:errors = []
  v:errmsg = ''

  const src_name = 'testfile.sh'
  const code_lines =<< trim END
_VIM_USER_VARS=()

# ─────────────────────────────
# Portable types

FOO="Hello"
_VIM_USER_VARS+=("FOO")

BAR=42
_VIM_USER_VARS+=("BAR")

ARR=("apple" "banana" "cherry")
_VIM_USER_VARS+=("ARR")

# %% ─────────────────────────────
# Shell-specific types

if [ -n "${BASH_VERSION:-}" ]; then
    # Bash associative array
    declare -A MAP=(
        [name]="bash"
        [type]="assoc"
    )
    _VIM_USER_VARS+=("MAP")

elif [ -n "${ZSH_VERSION:-}" ]; then
    # Zsh associative array
    typeset -A MAP
    MAP=(
        name zsh
        type assoc
    )
    _VIM_USER_VARS+=("MAP")
fi
END

  Generate_testfile(code_lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_name")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  var bufnr = term_list()[0]
  var term_cursor_pos = term_getcursor(bufnr)
  var expected_prompt = 'vim_replica>\s$'
  WaitForPrompt(expected_prompt)

  var lastline = LastNonEmptyLine(bufnr)
  assert_match(expected_prompt, lastline)

  # Send current buffer
  exe "ReplicaSendFile"
  WaitForPrompt(expected_prompt)

#   # -- Test float
  var expected_variable_explorer = ['Hello']
  var buf_name = 'FOO'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  var actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # --- test %whos
  #  TODO: test won't pass on Windows
  # OBS! The way %whos display variables, may change with the repl
  # versions, so you cannot really test it reliably. At most, you can check
  # that a split window happened

  exe "ReplicaInspect"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  buf_name = 'Workspace'
  assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test array
  expected_variable_explorer = ['(apple banana cherry)']
  buf_name = 'ARR'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test map
  expected_variable_explorer = ['type=assoc', 'name=bash']
  buf_name = 'MAP'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))


  # Shutoff
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('BASH')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  if !empty(v:errors)
    echom "Test failed!"
  else
    echom "Test passed!"
  endif

  :%bw!
  Cleanup_testfile(src_name)
enddef


def g:Test_sh_getcompletion()
  # g:replica_debug = true
  v:errmsg = ''
  v:errors = []
  messages clear

  const src_name = 'testfile.sh'
  const lines =<< trim END
_VIM_USER_VARS=()

# ─────────────────────────────
# Portable types

FOO="Hello"
_VIM_USER_VARS+=("FOO")

BAR=42
_VIM_USER_VARS+=("BAR")

ARR=("apple" "banana" "cherry")
_VIM_USER_VARS+=("ARR")

# %% ─────────────────────────────
# Shell-specific types

if [ -n "${BASH_VERSION:-}" ]; then
    # Bash associative array
    declare -A MAP=(
        [name]="bash"
        [type]="assoc"
    )
    _VIM_USER_VARS+=("MAP")

elif [ -n "${ZSH_VERSION:-}" ]; then
    # Zsh associative array
    typeset -A MAP
    MAP=(
        name zsh
        type assoc
    )
    _VIM_USER_VARS+=("MAP")
fi
  END

  Generate_testfile(lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_name")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  var bufnr = term_list()[0]
  var expected_prompt = 'vim_replica> $'
  WaitForPrompt(expected_prompt)

  var lastline = LastNonEmptyLine(bufnr)
  assert_match(expected_prompt, lastline)

  # Now the game starts
  exe 'ReplicaSendFile'
  redraw

  # test start
  const expected_value = ['FOO', 'BAR', 'APP', 'MAP']

  g:XXX = ftcm.funcs_dict.GetCompleteList
  const actual_value = getcompletion('', 'customlist,XXX')

  assert_equal(expected_value, actual_value)

  # ---- teardown tests ----
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('IPYTHON')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  if !empty(v:errors) || !empty(v:errmsg)
    echom "Test failed!"
  else
    echom "Test passed!"
  endif

  :%bw!
  Cleanup_testfile(src_name)
enddef
