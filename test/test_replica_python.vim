vim9script

# Test for the vim-replica plugin
# Copied and adjusted from Vim distribution

# OBS! Sometimes these tests fail!

import "../plugin/replica.vim"
import "../lib/repl.vim"

import "./common.vim"
var WaitForAssert = common.WaitForAssert

const init_ready_pattern = "Vim connected from "

def Generate_testfile(lines: list<string>, src_name: string)
  writefile(lines, src_name)
enddef

def Cleanup_testfile(src_name: string)
  delete(src_name)
enddef

def PatternCaught(buf_nr: number, pattern: string): bool
  # Return true if pattern appears in the visible window. This is useful when
  # there are asynchronous jobs around and they print in the console in
  # random order
  #
  # OBS! The following will not work, so we need to take the whole buffer
  # const startline = line('w0', win_id)
  # const endline = line('w$', win_id)
  #
  const win_id = bufwinid(buf_nr)
  const startline = 1
  const endline = line('$', win_id)
  # echom "lines: " .. string(getbufline(buf_nr, startline, endline))
  return getbufline(buf_nr, startline, endline)->map($"v:val =~# '{pattern}'")->index(true) != -1
enddef

# getbufline(bufnr(), line('w0'), min([line('w0') + &lines, line('$')]))->map($"v:val =~# 'Vim connected from'")->index(true) != -1
# When you read a terminal buffer with getbufline(buf_nr, 1, '$'), you get
# something like: ['bla bla', 'foo foo', '', 'bar bar', 'In [2]: ', '', '',
# '', '', '', '', '', '', '', '', '', '', '', '', '', '', ]
def LastNonEmptyLine(buf_nr: number): string
  var lines = getbufline(buf_nr, line('w0'), '$')
  for l in reverse(lines)
    if trim(l) !=# ''
      return l
    endif
  endfor
  return ''
enddef


def WaitForPrompt(expected: string)
  var counter = 0
  var period = 100
  const max_count = 200

  while counter < max_count && LastNonEmptyLine(b:repl_bufnr) !~# expected
    exe $"sleep {period}m"
    counter += 1
    redraw
  endwhile

  # Timeout reached, fail with actual last line
  if counter == max_count
    echoerr $"Prompt not found: {expected}, got: {LastNonEmptyLine(b:repl_bufnr)} after waiting {counter * period} ms"
  endif
enddef

def ReplStarted(
    repl_bufnr: number,
    pattern_1: string,
    pattern_2: string): bool

  # We have to secure that
  #   A. the REPL has stared,
  #   B. Vim is connected to the server,

  var counter = 0
  var counter_max = 100
  while !(PatternCaught(repl_bufnr, pattern_1)
      && PatternCaught(repl_bufnr, pattern_2))
        && counter < counter_max
    sleep 200m
    counter += 1
    redraw
  endwhile
   if counter == counter_max
     return false
   else
     return true
   endif
enddef

# Tests start here
def g:Test_python_basic()
  v:errors = []
  v:errmsg = ''
  messages clear

  if exepath('ipython')->empty()
    echoerr "Skipped: 'ipython' is not found in $PATH"
  endif

  const src_name = 'testfile.py'
  const lines =<< trim END
        FOO = 4
        b = 5

        # %%
        c = FOO + b

        # %%

        d = FOO - b
  END

  Generate_testfile(lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  if !empty(v:errmsg)
    :%bw!
    throw v:errmsg
  endif

  # The startup is done when both Vim is connected to the server and the repl
  # is ready (you see it from the prompt)
  var expected_prompt = 'In\s\[1\]:'

  if !ReplStarted(b:repl_bufnr, expected_prompt, init_ready_pattern)
    echoerr $"Failed to capture '{expected_prompt}' or '{init_ready_pattern}' string"
    return
  endif

  # ReplicaSendCell
  var lines_prompts = {4: 'In\s\[2\]:\s*$', 7: 'In\s\[3\]:\s*$', 9: 'In\s\[4\]:\s*$'}

  var lastline = ''
  for [line, prompt] in items(lines_prompts)
    exe "ReplicaSendCell"
    WaitForPrompt(prompt)
    lastline = LastNonEmptyLine(b:repl_bufnr)
    assert_match(prompt, lastline)
    # Check that in the editor you end up in the correct line
    assert_equal(str2nr(line), line('.'))
  endfor

  # ReplicaSendLine
  cursor(1, 1)
  lines_prompts = {2: 'In\s\[5\]:\s*$', 3: 'In\s\[6\]:\s*$'}

  for [line, prompt] in items(lines_prompts)
    exe "ReplicaSendLine"
    WaitForPrompt(prompt)
    redraw
    lastline = LastNonEmptyLine(b:repl_bufnr)
    assert_match(prompt, lastline)
    # Check that in the editor you end up in the correct line
    assert_equal(str2nr(line), line('.'))
  endfor

  # Double Toggle
  expected_prompt = 'In\s\[6\]:\s*$'
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(1, winnr('$')))
  WaitForAssert(() => assert_true(bufexists('IPYTHON')))
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))
  WaitForAssert(() => assert_true(bufexists('IPYTHON')))

  # Remove cells
  exe "ReplicaRemoveCells"
  WaitForAssert(() => assert_equal(search('# %%', 'cnw'), 0))

 # Restart repl
  exe "ReplicaConsoleRestart"
  expected_prompt = 'In\s\[1\]:\s*$'
  WaitForAssert(() => assert_equal(2, winnr('$')))
  sleep 200m

  if !ReplStarted(b:repl_bufnr, expected_prompt, init_ready_pattern)
    echoerr $"Failed to capture '{expected_prompt}' or '{init_ready_pattern}' string"
    return
  endif

  # ReplicaSendFile
  exe "ReplicaSendFile"
  expected_prompt = 'In\s\[2\]:\s*$'
  WaitForPrompt(expected_prompt)
  lastline = LastNonEmptyLine(b:repl_bufnr)
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_match(expected_prompt, lastline))

  # Shutoff
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('IPYTHON')))
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

def g:Test_unsupported_filetypes()
  # Test switching buffers of supported and unsupprted filetypes
  v:errmsg = ''
  v:errors = []
  messages clear

  # Generate text file
  const text_filename = 'text_testfile.txt'
  const text_file_lines =<< trim END
      This is nothing, but just a simple text file used
      for the purpose of testing this plugin.

      Nothing more than that.
      Bye.
  END

  Generate_testfile(text_file_lines, text_filename)
  exe $"edit {text_filename}"

  # Start console and fail, since 'text' filetype is not supported
  assert_fails('ReplicaConsoleToggle', 'E492:')
  # Check that the buffer variables are not set
  WaitForAssert(() => assert_true(empty(getbufvar(bufnr(), "repl_name"))))
  WaitForAssert(() => assert_true(empty(getbufvar(bufnr(), "console_name"))))

  # Generate python file
  const python_filename = 'python_testfile.py'
  const python_file_lines =<< trim END
      FOO = 2
      b = 3

      c = FOO + b
  END

  Generate_testfile(python_file_lines, python_filename)

  # Edit python file
  exe $"edit {python_filename}"

  # Check that the buffer variables are set
  WaitForAssert(() => assert_false(empty(getbufvar(bufnr(), "repl_name"))))
  WaitForAssert(() => assert_false(empty(getbufvar(bufnr(), "console_name"))))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))
  redraw
  WaitForPrompt('In\s\[1\]:\s*$')

  # switch buffer: python -> text
  exe $"b {bufnr(text_filename)}"

  # Start console and fail, since 'text' filetype is not supported
  assert_fails('ReplicaConsoleToggle', 'E492:')
  # Check that the buffer variables are not set
  WaitForAssert(() => assert_true(empty(getbufvar(bufnr(), "repl_name"))))
  WaitForAssert(() => assert_true(empty(getbufvar(bufnr(), "console_name"))))

  # switch buffer: text -> python
  exe $"b {bufnr(python_filename)}"

  # Check that the buffer variables are set
  WaitForAssert(() => assert_false(empty(getbufvar(bufnr(), "repl_name"))))
  WaitForAssert(() => assert_false(empty(getbufvar(bufnr(), "console_name"))))
  # Close console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(1, winnr('$')))

  exe "ReplicaConsoleShutoff"

  # ---- teardown tests ----
  if !empty(v:errors) || !empty(v:errmsg)
    echom "Test failed!"
  else
    echom "Test passed!"
  endif

  :%bw!
  Cleanup_testfile(python_filename)
  Cleanup_testfile(text_filename)
enddef

def g:Test_python_variable_explorer_basic()
  v:errmsg = ''
  v:errors = []
  messages clear

  const src_name = 'testfile.py'
  const lines =<< trim END
    import numpy as np
    import pandas as pd

    # Test single variable
    FOO = 110

    # Test numpy array
    A = np.array([[1, 2, 3], [4, 5, 6]])

    # Test pandas dataframe
    df = pd.DataFrame(A, columns=["a", "b", "c"], index=["row1", "row2"])
  END

  Generate_testfile(lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  if !empty(v:errmsg)
    :%bw!
    throw v:errmsg
  endif

  # The startup is done when both Vim is connected to the server and the repl
  # is ready (you see it from the prompt)
  var expected_prompt = 'In\s\[1\]:'

  if !ReplStarted(b:repl_bufnr, expected_prompt, init_ready_pattern)
    echoerr $"Failed to capture '{expected_prompt}' or '{init_ready_pattern}' string"
    return
  endif

  # Send current buffer
  exe "ReplicaSendFile"
  expected_prompt = 'In\s\[2\]:\s*$'
  WaitForPrompt(expected_prompt)

  # -- Test float
  var expected_variable_explorer = ['110']
  var buf_name = 'FOO'
  exe $"ReplicaInspect {buf_name}"
  # TODO: replace by checking if the response from server is non-empty
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

  # exe "ReplicaInspect"
  # WaitForAssert(() => assert_equal(3, winnr('$')))
  # redraw

  # buf_name = 'Workspace'
  # assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  # # Test <esc> mapping
  # exe "norm \<esc>"
  # WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test np.ndarray
  expected_variable_explorer = [
    "1\t2\t3",
    "4\t5\t6",
  ]
  buf_name = 'A'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # Test np.ndarray slice
  expected_variable_explorer = ["1\t2\t3"]

  buf_name = 'A[0, :]'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))

  actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test pd.DataFrame
  expected_variable_explorer =<< END
      a  b  c
row1  1  2  3
row2  4  5  6
END

  buf_name = 'df'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test pd.DataFrame slice (= pd.Series)
  expected_variable_explorer =<< END
row1    1
row2    4
END
  buf_name = "df['a']"
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # Shutoff
  wincmd p
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('IPYTHON')))
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

def g:Test_python_getcompletion()
  v:errmsg = ''
  v:errors = []
  messages clear

  const src_name = 'testfile.py'
  const lines =<< trim END
    import numpy as np
    import pandas as pd

    # Test single variable
    FOO = 110

    # Test numpy array
    A = np.array([[1, 2, 3], [4, 5, 6]])

    # Test pandas dataframe
    df = pd.DataFrame(A, columns=["a", "b", "c"], index=["row1", "row2"])
  END

  Generate_testfile(lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  if !empty(v:errmsg)
    :%bw!
    throw v:errmsg
  endif

  # The startup is done when both Vim is connected to the server and the repl
  # is ready (you see it from the prompt)
  var expected_prompt = 'In\s\[1\]:'

  if !ReplStarted(b:repl_bufnr, expected_prompt, init_ready_pattern)
    echoerr $"Failed to capture '{expected_prompt}' or '{init_ready_pattern}' string"
    return
  endif

  # Now the game starts
  exe 'ReplicaSendFile'
  expected_prompt = 'In\s\[2\]:\s*$'
  WaitForPrompt(expected_prompt)
  redraw

  var lastline = LastNonEmptyLine(b:repl_bufnr)
  assert_match(expected_prompt, lastline)

  # test start
  const expected_value = ['A', 'FOO', 'df']

  g:XXX = repl.funcs_dict.GetCompleteList
  const actual_value = getcompletion('', 'customlist,XXX')

  assert_equal(expected_value, actual_value)

  # ---- teardown tests ----
  # exe "ReplicaConsoleShutoff"
  # WaitForAssert(() => assert_false(bufexists('IPYTHON')))
  # WaitForAssert(() => assert_equal(1, winnr('$')))

  if !empty(v:errors) || !empty(v:errmsg)
    echom "Test failed!"
  else
    echom "Test passed!"
  endif

  :%bw!
  Cleanup_testfile(src_name)
enddef
