vim9script

# Test for the vim-replica plugin
# Copied and adjusted from Vim distribution

# OBS! Sometimes these tests fail!

# Uncomment for debug
import "../plugin/replica.vim"

import "./common.vim"
var WaitForAssert = common.WaitForAssert

var jupyter_console = exepath('jupyter-console')
if jupyter_console->empty()
  throw 'Skipped: jupyter_console is not found in $PATH'
endif

def Generate_testfile(lines: list<string>, src_name: string)
  writefile(lines, src_name)
enddef

def Cleanup_testfile(src_name: string)
  delete(src_name)
enddef

# When you read a terminal buffer with getbufline(buf_nr, 1, '$'), you get
# something like: ['bla bla', 'foo foo', '', 'bar bar', 'In [2]: ', '', '',
# '', '', '', '', '', '', '', '', '', '', '', '', '', '', ]
def LastNonEmptyLine(buf_nr: number): string
  var lines = getbufline(buf_nr, 1, '$')
  for ii in range(len(lines) - 1, 0, -1)
    if trim(lines[ii]) !=# ''
      return lines[ii]
    endif
  endfor
  return ''
enddef

def WaitForStableLastLine(): string
  # If last line does not change for a while, it is returned
  const buf_nr = term_list()[0]

  # Wait for terminal to startup
  var counter = 0
  const max_count = 200

  while counter < max_count
    if !empty(LastNonEmptyLine(buf_nr))
      break
    else
      sleep 50m
      counter += 1
    endif
  endwhile

  if counter >= max_count
    throw 'REPL startup timeout: no output detected'
  endif

  # A line that does not change for some time is stable, but let's also add a
  # hard timeout
  var prev = ''
  var stable = 0
  const max_stable = 3

  counter = 0
  while stable < max_stable && counter < max_count
    var cur = LastNonEmptyLine(buf_nr)

    if cur ==# prev
      stable += 1
    else
      stable = 0
      prev = cur
    endif

    sleep 50m
    counter += 1
  endwhile

  if counter >= max_count
    throw "REPL got frozen"
  endif

  return prev
enddef

def WaitForPrompt(expected: string)
  const buf_nr = term_list()[0]
  var counter = 0
  const max_count = 400  # 400*50ms = 20 seconds max

  while counter < max_count
    var line = LastNonEmptyLine(buf_nr)
    if line =~# expected
      # Prompt appeared, return immediately
      return
    endif
    sleep 50m
    counter += 1
  endwhile

  # Timeout reached, fail with actual last line
  var line = LastNonEmptyLine(buf_nr)
  throw $"Prompt not found: {expected}, got: {line}"
enddef

def WaitForPromptOld(expected: string)
  const buf_nr = term_list()[0]

  # Wait until last line changes from old prompt
  var prev_line = LastNonEmptyLine(buf_nr)
  var counter = 0
  const max_count = 200

  while counter < max_count
    var cur_line = LastNonEmptyLine(buf_nr)
    if cur_line !=# prev_line
      break
    endif
    sleep 50m
    counter += 1
  endwhile

  var line = WaitForStableLastLine()
  if line !~# expected
    throw $"Prompt not found: {expected}, got: {line}"
  endif
enddef

# Tests start here
def g:Test_python_basic()

  messages clear

  const src_name = 'testfile.py'
  const lines =<< trim END
        a = 4
        b = 5

        # %%
        c = a + b

        # %%

        d = a - b
  END

  Generate_testfile(lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "kernel_name")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  var expected_prompt = 'In \[2\]'
  WaitForPrompt(expected_prompt)

  var bufnr = term_list()[0]
  var lastline = LastNonEmptyLine(bufnr)
  echom  assert_match(expected_prompt, lastline)

  # ReplicaSendCell
  var lines_prompts = {4: 'In \[3\]', 7: 'In \[4\]', 9: 'In \[5\]'}

  for [line, prompt] in items(lines_prompts)
    exe "ReplicaSendCell"
    WaitForPrompt(prompt)
    lastline = LastNonEmptyLine(bufnr)
    echom assert_match(prompt, lastline)
    # Check that in the editor you end up in the correct line
    echom assert_equal(str2nr(line), line('.'))
  endfor

  # ReplicaSendLine
  cursor(1, 1)
  lines_prompts = {2: 'In \[6\]', 3: 'In \[7\]'}

  for [line, prompt] in items(lines_prompts)
    exe "ReplicaSendLine"
    WaitForPrompt(prompt)
    lastline = LastNonEmptyLine(bufnr)
    echom assert_match(prompt, lastline)
    # Check that in the editor you end up in the correct line
    echom assert_equal(str2nr(line), line('.'))
  endfor

  # Double Toggle
  expected_prompt = 'In \[7\]'
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(1, winnr('$')))
  WaitForAssert(() => assert_true(bufexists('IPYTHON')))
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))
  WaitForAssert(() => assert_true(bufexists('IPYTHON')))

  # Remove cells
  exe "ReplicaRemoveCells"
  WaitForAssert(() => assert_equal(search(g:replica_cells_delimiters.python, 'cnw'), 0))

  # Restart kernel
  exe "ReplicaConsoleRestart"
  expected_prompt = 'In \[2\]'
  WaitForPrompt(expected_prompt)
  bufnr = term_list()[0]
  lastline = LastNonEmptyLine(bufnr)
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_match(expected_prompt, lastline))

  # ReplicaSendFile
  exe "ReplicaSendFile"
  expected_prompt = 'In \[3\]'
  WaitForPrompt(expected_prompt)
  lastline = LastNonEmptyLine(bufnr)
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_match(expected_prompt, lastline))

  # Shutoff
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('IPYTHON')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  :%bw!
  Cleanup_testfile(src_name)
enddef

def g:Test_unsupported_filetypes()
  # Test switching buffers of supported and unsupprted filetypes

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
  echom assert_fails('ReplicaConsoleToggle', 'E492:')
  # Check that the buffer variables are not set
  WaitForAssert(() => assert_true(empty(getbufvar(bufnr(), "kernel_name"))))
  WaitForAssert(() => assert_true(empty(getbufvar(bufnr(), "console_name"))))

  # Generate python file
  const python_filename = 'python_testfile.py'
  const python_file_lines =<< trim END
      a = 2
      b = 3

      c = a + b
  END

  Generate_testfile(python_file_lines, python_filename)

  # Edit python file
  exe $"edit {python_filename}"

  # Check that the buffer variables are set
  WaitForAssert(() => assert_false(empty(getbufvar(bufnr(), "kernel_name"))))
  WaitForAssert(() => assert_false(empty(getbufvar(bufnr(), "console_name"))))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForPrompt('[2]')

  # switch buffer: python -> text
  exe "bnext"

  # Start console and fail, since 'text' filetype is not supported
  assert_fails('ReplicaConsoleToggle', 'E492:')
  # Check that the buffer variables are not set
  WaitForAssert(() => assert_true(empty(getbufvar(bufnr(), "kernel_name"))))
  WaitForAssert(() => assert_true(empty(getbufvar(bufnr(), "console_name"))))

  # switch buffer: text -> python
  exe "bnext"

  # Check that the buffer variables are set
  WaitForAssert(() => assert_false(empty(getbufvar(bufnr(), "kernel_name"))))
  WaitForAssert(() => assert_false(empty(getbufvar(bufnr(), "console_name"))))
  # Close console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(1, winnr('$')))

  exe "ReplicaConsoleShutoff"

  :%bw!
  Cleanup_testfile(python_filename)
  Cleanup_testfile(text_filename)
enddef

def g:Test_variable_explorer_basic()
  messages clear

  const src_name = 'testfile.py'
  const lines =<< trim END
    import numpy as np
    import pandas as pd

    # Test single variable
    a = 110

    # Test numpy array
    A = np.array([[1, 2, 3], [4, 5, 6]])

    # Test pandas dataframe
    df = pd.DataFrame(A, columns=["a", "b", "c"], index=["row1", "row2"])
  END

  Generate_testfile(lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "kernel_name")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  var bufnr = term_list()[0]
  var term_cursor_pos = term_getcursor(bufnr)
  var term_cursor = term_getline(bufnr, term_cursor_pos[0])
  var expected_prompt = '\[2\]'
  WaitForPrompt(expected_prompt)

  var lastline = LastNonEmptyLine(bufnr)
  assert_match(expected_prompt, lastline)

  # Send current buffer
  exe "ReplicaSendFile"

  # -- Test float
  var expected_variable_explorer = ['110']
  var buf_name = 'a'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  var actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  echom assert_equal(actual_variable_explorer, expected_variable_explorer)
  echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # --- test %whos
  #  TODO: test won't pass on Windows
  # OBS! The way %whos display variables, may change with the kernel
  # versions, so you cannot really test it reliably. At most, you can check
  # that a split window happened

  # exe "ReplicaInspect"
  # WaitForAssert(() => assert_equal(3, winnr('$')))
  # redraw

  # buf_name = 'Workspace'
  # echom assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  # # Test <esc> mapping
  # exe "norm \<esc>"
  # WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test np.ndarray
  expected_variable_explorer = [
    "1\t2\t3",
    "4\t5\t6"
  ]
  buf_name = 'A'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  echom assert_equal(actual_variable_explorer, expected_variable_explorer)
  echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # Test np.ndarray slice
  expected_variable_explorer = ["1\t2\t3"]

  buf_name = 'A[0, :]'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))

  actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  echom assert_equal(expected_variable_explorer, actual_variable_explorer)
  echom assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  # Test <esc> mapping
  exe "norm \<esc>"
  echom WaitForAssert(() => assert_equal(2, winnr('$')))

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
  echom assert_equal(actual_variable_explorer, expected_variable_explorer)
  echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

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
  echom assert_equal(actual_variable_explorer, expected_variable_explorer)
  echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # Shutoff
  wincmd p
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('IPYTHON')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  :%bw!
  Cleanup_testfile(src_name)
enddef
