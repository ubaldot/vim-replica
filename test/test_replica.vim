vim9script

# Test for the vim-replica plugin
# Copied and adjusted from Vim distribution

# OBS! Sometimes these tests fail!

# Uncomment for debug
# import "../plugin/replica.vim"

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

def WaitPrompt(expected_prompt: string)
  # Wait for Jupyter Console to be up and running
  const bufnr = term_list()[0]
  var term_cursor_pos = term_getcursor(bufnr)
  var term_cursor = term_getline(bufnr, term_cursor_pos[0])

  var count = 0
  const max_count = 10
  while term_cursor !~ expected_prompt && count < max_count
    redraw!
    term_cursor_pos = term_getcursor(bufnr)
    term_cursor = term_getline(bufnr, term_cursor_pos[0])
    count += 1
    sleep 1
  endwhile
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

        d = a -b
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
  var expected_prompt = '[2]'
  WaitPrompt(expected_prompt)

  term_cursor_pos = term_getcursor(bufnr)
  var lastline = term_getline(bufnr, term_cursor_pos[0])
  assert_match(expected_prompt, lastline)

  # ReplicaSendCell
  # {prompt_in_ipython_console: line_in_src_buffer}
  var prompts_lines = {3: 4, 4: 7, 5: 9}

  for [prompt, line] in items(prompts_lines)
      expected_prompt = prompt
      exe "ReplicaSendCell"
      WaitPrompt($'[{prompt}]')
      term_cursor_pos = term_getcursor(bufnr)
      lastline = term_getline(bufnr, term_cursor_pos[0])
      assert_true(line('.') == line)
  endfor

  # ReplicaSendLine
  cursor(1, 1)
  prompts_lines = {6: 2, 7: 3}

  for [prompt, line] in items(prompts_lines)
      exe "ReplicaSendLine"
      WaitPrompt($'[{prompt}]')
      expected_prompt = prompt
      term_cursor_pos = term_getcursor(bufnr)
      lastline = term_getline(bufnr, term_cursor_pos[0])
      assert_true(lastline =~# expected_prompt)
      assert_true(line('.') == line)
  endfor

  # Double Toggle
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
  expected_prompt = '[2]'
  WaitPrompt(expected_prompt)
  bufnr = term_list()[0]
  term_cursor_pos = term_getcursor(bufnr)
  lastline = term_getline(bufnr, term_cursor_pos[0])
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))

  # ReplicaSendFile
  exe "ReplicaSendFile"
  expected_prompt = '[3]'
  WaitPrompt(expected_prompt)
  term_cursor_pos = term_getcursor(bufnr)
  lastline = term_getline(bufnr, term_cursor_pos[0])
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))

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
  assert_fails('ReplicaConsoleToggle', 'E492:')
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
  WaitPrompt('[1]')

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
	# messages clear

  const src_name = 'testfile.py'
  const lines =<< trim END
    import numpy as np
    import pandas as pd

    # Test single variable
    a = 3.99

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
  var expected_prompt = '[2]'
  WaitPrompt(expected_prompt)

  term_cursor_pos = term_getcursor(bufnr)
  var lastline = term_getline(bufnr, term_cursor_pos[0])
  assert_match(expected_prompt, lastline)

  # Send current buffer
  exe "ReplicaSendFile"

  # test %whos
  # OBS! The way %whos display variables, may change with the kernel
  # versions, so you cannot really test it reliably. At most, you can check
  # that a split window happened

  exe "ReplicaInspect"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  var buf_name = 'Workspace'
  echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

  # Test <esc> mapping
  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test float
  # var expected_variable_explorer = ['3.99']
  # buf_name = 'a'
  # exe $"ReplicaInspect {buf_name}"
  # WaitForAssert(() => assert_equal(3, winnr('$')))
  # redraw

  # var actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  # echom assert_equal(actual_variable_explorer, expected_variable_explorer)
  # echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

  # # Test <esc> mapping
  # exe "norm \<esc>"
  # WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test np.ndarray
#   expected_variable_explorer =<< END
# 1	2	3
# 4	5	6
# END
#   buf_name = 'A'
#   exe $"ReplicaInspect {buf_name}"
#   WaitForAssert(() => assert_equal(3, winnr('$')))
#   redraw

#   actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   echom assert_equal(actual_variable_explorer, expected_variable_explorer)
#   echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

  # TODO: Test np.ndarray slice DOES NOT WORK
#   expected_variable_explorer =<< END
# 1	2	3
# 4	5	6
# END
#   exe "ReplicaInspect A"
#   WaitForAssert(() => assert_equal(3, winnr('$')))

#   buf_name = 'A'
#   actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   echom assert_equal(actual_variable_explorer, expected_variable_explorer)
#   echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   echom WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test pd.DataFrame
#   expected_variable_explorer =<< END
#       a  b  c
# row1  1  2  3
# row2  4  5  6
# END

#   buf_name = 'df'
#   exe $"ReplicaInspect {buf_name}"
#   WaitForAssert(() => assert_equal(3, winnr('$')))
#   redraw

#   actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   echom assert_equal(actual_variable_explorer, expected_variable_explorer)
#   echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test pd.DataFrame slice (= pd.Series)
#   expected_variable_explorer =<< END
# row1    1
# row2    4
# END
#   buf_name = "df['a']"
#   exe $"ReplicaInspect {buf_name}"
#   WaitForAssert(() => assert_equal(3, winnr('$')))
#   redraw

#   actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   echom assert_equal(actual_variable_explorer, expected_variable_explorer)
#   echom assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

#   # Shutoff
#   wincmd p
#   exe "ReplicaConsoleShutoff"
#   WaitForAssert(() => assert_false(bufexists('IPYTHON')))
#   WaitForAssert(() => assert_equal(1, winnr('$')))

  :%bw!
  Cleanup_testfile(src_name)

enddef
