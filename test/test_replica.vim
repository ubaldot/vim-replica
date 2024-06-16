vim9script

# Test for the vim-replica plugin
# Copied and adjusted from Vim distribution

import "./common.vim"
var WaitForAssert = common.WaitForAssert

var jupyter_console = exepath('jupyter-console')
if jupyter_console->empty()
  throw 'Skipped: jupyter_console is not found in $PATH'
endif

var src_name = 'testfile.py'

def Generate_python_testfile()
  var lines =<< trim END
        a = 4
        b = 5

        # %%
        c = a + b

        # %%

        d = a -b
  END
   writefile(lines, src_name)
enddef

def Cleanup_python_testfile()
   delete(src_name)
enddef

# Tests start here
def g:Test_replica_basic()
  Generate_python_testfile()

  exe $"edit {src_name}"
  ReplicaConsoleToggle
  WaitForAssert(() => assert_equal(2, winnr('$')))
  # TODO: Check how to remove the sleep
  # It must be very generous otherwise the CI tests won't pass.
  sleep 4
  redraw!

  var bufnr = term_list()[0]
  var term_cursor = term_getcursor(bufnr)
  var lastline = term_getline(bufnr, term_cursor[0])

  var expected_prompt = '[1]'
  assert_true(lastline =~# expected_prompt)

  # ReplicaSendCell
  # {prompt_in_ipython_console: line_in_src_buffer}
  var prompts_lines = {2: 4, 3: 7, 4: 9}

  for [prompt, line] in items(prompts_lines)
      ReplicaSendCell
      sleep 2
      redraw!
      expected_prompt = prompt
      term_cursor = term_getcursor(bufnr)
      lastline = term_getline(bufnr, term_cursor[0])
      WaitForAssert(() => assert_true(lastline =~# expected_prompt))
      assert_true(line('.') == line)
  endfor

  # ReplicaSendLine
  cursor(1, 1)
  prompts_lines = {5: 2, 6: 3}

  for [prompt, line] in items(prompts_lines)
      ReplicaSendLine
      sleep 1
      redraw!
      expected_prompt = prompt
      term_cursor = term_getcursor(bufnr)
      lastline = term_getline(bufnr, term_cursor[0])
      WaitForAssert(() => assert_true(lastline =~# expected_prompt))
      assert_true(line('.') == line)
  endfor

  # Double Toggle
  ReplicaConsoleToggle
  WaitForAssert(() => assert_equal(1, winnr('$')))
  ReplicaConsoleToggle
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))

  # Restart kernel
  ReplicaConsoleRestart
  sleep 4
  redraw!
  bufnr = term_list()[0]
  term_cursor = term_getcursor(bufnr)
  lastline = term_getline(bufnr, term_cursor[0])
  expected_prompt = '[1]'
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))

  # Shutoff
  ReplicaConsoleShutoff
  WaitForAssert(() => assert_equal(1, winnr('$')))

  Cleanup_python_testfile()
enddef
