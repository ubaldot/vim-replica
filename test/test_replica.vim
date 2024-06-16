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

        # %%
        print('last_line')
  END
   writefile(lines, src_name)
enddef

def Cleanup_python_testfile()
   delete(src_name)
enddef

def LastIpythonNonBlankLine(bufnrr: number): string
    var current_buf = bufnr()
    exe $'buffer {bufnrr}'
    var lnum = line('$')
    var lval = getbufline(bufnrr, lnum)[0]
    exe $'buffer {current_buf}'

    while lnum > 0 && getbufline(bufnrr, lnum)[0] =~ '^\s*$'
        lnum -= 1
        lval = getbufline(bufnrr, lnum)[0]
    endwhile
    return lval
enddef

# Tests start here
def g:Test_replica_basic()
  Generate_python_testfile()

  exe $"edit {src_name}"
  ReplicaConsoleToggle
  WaitForAssert(() => assert_equal(2, winnr('$')))
  # TODO: Check how to remove the sleep
  sleep 4
  redraw!

  var bufnr = term_list()[0]

  var lastline = LastIpythonNonBlankLine(bufnr)
  var expected_prompt = '[1]'
  assert_true(lastline =~# expected_prompt)

  Cleanup_python_testfile()
enddef
