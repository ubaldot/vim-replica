vim9script

# Test for the vim-replica plugin - R language

import "../plugin/replica.vim"
import "../lib/repl.vim"

import "./common.vim"
const WaitForAssert  = common.WaitForAssert
const WaitForPrompt  = common.WaitForPrompt
const LastNonEmptyLine = common.LastNonEmptyLine
const PatternCaught  = common.PatternCaught
const ReplStarted    = common.ReplStarted
const Generate_testfile = common.Generate_testfile
const Cleanup_testfile  = common.Cleanup_testfile

const expected_prompt    = '^>\s*'
const init_ready_pattern = "Vim connected"

const src_name = 'testfile.r'

# ---------------------------------------------------------------------------
# Test data — defined at top level so heredoc content is at column 0
# ---------------------------------------------------------------------------

const basic_lines =<< trim END
FOO <- 110
b <- 5

# %%
c <- FOO + b

# %%

d <- FOO - b
END

const var_explorer_lines =<< trim END
FOO <- 110
vec <- c(1, 2, 3)
mat <- matrix(1:6, nrow = 2)
END

const completion_lines =<< trim END
FOO <- 110
A <- c(1, 2, 3)
df <- data.frame(x = 1:2)
END

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def g:Test_R_basic()
  v:errors = []
  v:errmsg = ''
  messages clear

  if exepath('R')->empty()
    throw "Skipped: 'R' executable is not found in $PATH"
  endif

  Generate_testfile(basic_lines, src_name)
  exe $"edit {src_name}"

  # Check that buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  if !empty(v:errmsg)
    :%bw!
    throw v:errmsg
  endif

  if !ReplStarted(b:console_bufnr, expected_prompt, init_ready_pattern)
    exe "ReplicaConsoleShutoff"
    # :%bw!
    echoerr $"Failed to capture '{expected_prompt}' or '{init_ready_pattern}'"
    return
  endif

  # ReplicaSendCell — basic_lines has # %% at lines 4 and 7; last line is 9
  cursor(1, 1)
  const cell_lines = [4, 7, 9]

  var lastline = ''
  for expected_line in cell_lines
    exe "ReplicaSendCell"
    WaitForPrompt(expected_prompt)
    lastline = LastNonEmptyLine(b:console_bufnr)
    assert_match(expected_prompt, lastline)
    assert_equal(expected_line, line('.'))
  endfor

  # ReplicaSendLine
  cursor(1, 1)
  const send_line_targets = [2, 3]

  for expected_line in send_line_targets
    exe "ReplicaSendLine"
    WaitForPrompt(expected_prompt)
    assert_equal(expected_line, line('.'))
  endfor

  # Double Toggle
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(1, winnr('$')))
  WaitForAssert(() => assert_true(bufexists('R')))
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))
  WaitForAssert(() => assert_true(bufexists('R')))

  # Remove cells
  exe "ReplicaRemoveCells"
  WaitForAssert(() => assert_equal(search('# %%', 'cnw'), 0))

  # Restart repl
  exe "ReplicaConsoleRestart"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  if !ReplStarted(b:console_bufnr, expected_prompt, init_ready_pattern)
    exe "ReplicaConsoleShutoff"
    :%bw!
    echoerr $"Failed to capture '{expected_prompt}' or '{init_ready_pattern}' after restart"
    return
  endif

  # ReplicaSendFile
  exe "ReplicaSendFile"
  WaitForPrompt(expected_prompt)
  lastline = LastNonEmptyLine(b:console_bufnr)
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_match(expected_prompt, lastline))

  # Shutoff
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('R')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  if !empty(v:errors) || !empty(v:errmsg)
    echom "Test failed!"
  else
    echom "Test passed!"
  endif

  :%bw!
  Cleanup_testfile(src_name)
enddef


def g:Test_R_variable_explorer_basic()
  v:errors = []
  v:errmsg = ''
  messages clear

  Generate_testfile(var_explorer_lines, src_name)
  exe $"edit {src_name}"

  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  if !empty(v:errmsg)
    :%bw!
    throw v:errmsg
  endif

  if !ReplStarted(b:console_bufnr, expected_prompt, init_ready_pattern)
    exe "ReplicaConsoleShutoff"
    :%bw!
    echoerr $"Failed to capture '{expected_prompt}' or '{init_ready_pattern}'"
    return
  endif

  sleep 20m
  term_sendkeys(b:console_bufnr, "\n")
  redraw

  # Send current buffer
  exe "ReplicaSendFile"
  WaitForPrompt(expected_prompt)
  sleep 200m
  redraw

  # -- Test scalar
  var expected_variable_explorer = ['[1] 110']
  var buf_name = 'FOO'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  var actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test vector
  expected_variable_explorer = ['[1] 1 2 3']
  buf_name = 'vec'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw


  actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test workspace (:ReplicaInspect with no argument)
  exe "ReplicaInspect"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  buf_name = 'Workspace'
  assert_equal($'{buf_name}', &l:statusline)

  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # Shutoff
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('R')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  if !empty(v:errors) || !empty(v:errmsg)
    echom "Test failed!"
  else
    echom "Test passed!"
  endif

  :%bw!
  Cleanup_testfile(src_name)
enddef


def g:Test_R_getcompletion()
  v:errors = []
  v:errmsg = ''
  messages clear

  Generate_testfile(completion_lines, src_name)
  exe $"edit {src_name}"

  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  if !empty(v:errmsg)
    :%bw!
    throw v:errmsg
  endif

  if !ReplStarted(b:console_bufnr, expected_prompt, init_ready_pattern)
    exe "ReplicaConsoleShutoff"
    :%bw!
    echoerr $"Failed to capture '{expected_prompt}' or '{init_ready_pattern}'"
    return
  endif

  exe 'ReplicaSendFile'
  WaitForPrompt(expected_prompt)
  redraw

  # completion_lines defines: A, FOO, df  →  sorted: A, FOO, df
  const expected_value = ['A', 'FOO', 'df']

  g:XXX = repl.funcs_dict.GetCompleteList
  const actual_value = getcompletion('', 'customlist,XXX')

  assert_equal(expected_value, actual_value)

  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('R')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  if !empty(v:errors) || !empty(v:errmsg)
    echom "Test failed!"
  else
    echom "Test passed!"
  endif

  :%bw!
  Cleanup_testfile(src_name)
enddef
