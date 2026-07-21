vim9script

# Basic test for zsh filetype support in vim-replica.

import "./common.vim"
const WaitForAssert     = common.WaitForAssert
const WaitForPrompt     = common.WaitForPrompt
const LastNonEmptyLine  = common.LastNonEmptyLine
const StartConsole      = common.StartConsole
const TestReport        = common.TestReport
const Generate_testfile = common.Generate_testfile
const Cleanup_testfile  = common.Cleanup_testfile

# zsh -f -i (no rc files) shows a prompt ending in % (or %% for a literal %)
const expected_prompt = '%\s*$'

const src_name = 'testfile.zsh'
const code_lines =<< trim END
  # %%
  X=hello
  echo "$X"
  # %%
  Y=world
  echo "$Y"
END

def g:Test_zsh_basic()
  v:errors = []
  v:errmsg = ''
  messages clear

  if exepath('zsh')->empty()
    echom "Skipped: 'zsh' not found in PATH"
    return
  endif

  Generate_testfile(code_lines, src_name)
  exe $"edit {src_name}"
  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  # No TCP server for zsh — pass '' as init_ready_pattern
  if !StartConsole(expected_prompt, '')
    return
  endif

  # ReplicaSendCell
  cursor(1, 1)
  exe "ReplicaSendCell"
  WaitForPrompt(expected_prompt)
  exe "ReplicaSendCell"
  WaitForPrompt(expected_prompt)

  # ReplicaSendLine
  cursor(2, 1)
  exe "ReplicaSendLine"
  WaitForPrompt(expected_prompt)

  # Double Toggle
  var lastline = LastNonEmptyLine(b:console_bufnr)
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(1, winnr('$')))
  WaitForAssert(() => assert_true(bufexists('ZSH')))
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))

  # Remove cells
  exe "ReplicaRemoveCells"
  WaitForAssert(() => assert_equal(search('# %%', 'cnw'), 0))

  # Restart
  if !StartConsole(expected_prompt, '', "ReplicaConsoleRestart")
    return
  endif

  # ReplicaSendFile
  exe "ReplicaSendFile"
  WaitForPrompt(expected_prompt)

  # Shutoff
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('ZSH')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  TestReport()
  :%bw!
  Cleanup_testfile(src_name)
enddef
