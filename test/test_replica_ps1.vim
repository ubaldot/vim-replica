vim9script

# Basic test for ps1 (PowerShell) filetype support in vim-replica.

import "./common.vim"
const WaitForAssert     = common.WaitForAssert
const WaitForPrompt     = common.WaitForPrompt
const LastNonEmptyLine  = common.LastNonEmptyLine
const StartConsole      = common.StartConsole
const TestReport        = common.TestReport
const Generate_testfile = common.Generate_testfile
const Cleanup_testfile  = common.Cleanup_testfile

# pwsh default prompt ends in "> " (e.g. "PS C:\path> " or "PS /home/user> ")
const expected_prompt = '>\s*$'

const src_name = 'testfile.ps1'
const code_lines =<< trim END
  # %%
  $X = "hello"
  Write-Output $X
  # %%
  $Y = "world"
  Write-Output $Y
END

def g:Test_ps1_basic()
  v:errors = []
  v:errmsg = ''
  messages clear

  if exepath('pwsh')->empty()
    echom "Skipped: 'pwsh' not found in PATH"
    return
  endif

  Generate_testfile(code_lines, src_name)
  exe $"edit {src_name}"
  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  # No TCP server for ps1 — pass '' as init_ready_pattern
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
  WaitForAssert(() => assert_true(bufexists('PWSH')))
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
  WaitForAssert(() => assert_false(bufexists('PWSH')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  TestReport()
  :%bw!
  Cleanup_testfile(src_name)
enddef
