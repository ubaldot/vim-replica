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

def g:Test_replica_basic()
  Generate_python_testfile()

  filetype plugin indent on
  exe $"edit {src_name}"
  ReplicaConsoleToggle

  WaitForAssert(() => assert_equal(2, winnr('$')))

  # TODO: Wait for ipython startup
  sleep 1
  var bufnr = term_list()[0]
  var ipython_banner_length = 6
  var last_line =  term_getline(bufnr, ipython_banner_length + 1)
  WaitForAssert(() => assert_true(last_line =~# '[1]'))

  Cleanup_python_testfile()
enddef
