vim9script

# Test for the vim-replica plugin
# Copied and adjusted from Vim distribution

# OBS! Sometimes these tests fail!

# Uncomment for debug
import "../plugin/replica.vim"

import "./common.vim"
var WaitForAssert = common.WaitForAssert

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

def WaitForPrompt(expected: string)
  const buf_nr = term_list()[0]
  var counter = 0
  const max_count = 50 * 2  # 20*(2*50ms) = 20 seconds max
  var line = ''

  while counter < max_count
    line = LastNonEmptyLine(buf_nr)
    if line =~# expected
      # Expected prompt appeared, return immediately
      return
    endif
    sleep 50m
    counter += 1
  endwhile

  # Timeout reached, fail with actual last line
  throw $"Prompt not found: {expected}, got: {line} after waiting {counter * 50} ms"
enddef

def WaitForJuliaSymbol(symbol: string)
  const buf_nr = term_list()[0]
  const marker = '__VIM_REPLICA_READY__:'
  const max_count = 40
  var counter = 0
  var line = ''

  while counter < max_count
    term_sendkeys(
      buf_nr,
      $"println(\"{marker}\", isdefined(Main, :{symbol}))\n"
    )
    sleep 100m
    line = LastNonEmptyLine(buf_nr)
    if line ==# $"{marker}true"
      return
    endif
    counter += 1
  endwhile

  throw $"Julia symbol not ready: {symbol}"
enddef
# Tests start here
def g:Test_julia_basic()

  # g:replica_debug = true
  v:errors = []
  messages clear

  const src_name = 'testfile.jl'
  const code_lines =<< trim END
"""
Test file for vim-replica (Julia)

Includes:
- Simple scalar variables
- 1D, 2D, and 3D arrays
- DataFrames
"""

using DataFrames
using Dates


# %% -----------------
# Simple variables
# --------------------
a_int   = 42
a_float = 3.14159
a_str   = "vim-replica test"
a_bool  = true
a_nothing = nothing


# --------------------
# 1D arrays (Vectors)
# --------------------
vec_int = [1, 2, 3, 4, 5]
vec_float = [0.1, 0.2, 0.3]
vec_mixed = [1.0, 2.5, 3.75]


# %% -----------------
# 2D arrays (Matrices)
# --------------------
mat_int = [
    1 2 3
    4 5 6
]

mat_float = [
    0.1 0.2
    0.3 0.4
    0.5 0.6
]


# --------------------
# 3D arrays
# --------------------
arr_3d = reshape(collect(1:8), 2, 2, 2)
# Dimensions: (2, 2, 2)
# arr_3d[:, :, 1] = [1 3; 2 4]
# arr_3d[:, :, 2] = [5 7; 6 8]


# --------------------
# DataFrames
# --------------------
df_simple = DataFrame(
    A = [1, 2, 3],
    B = [4, 5, 6],
)

# %%
df_mixed = DataFrame(
    time  = Date(2024, 1, 1):Day(1):Date(2024, 1, 4),
    value = [0.1, 0.2, 0.3, 0.4],
    flag  = [true, false, true, false],
)

df_categorical = DataFrame(
    category = ["x", "x", "y", "y"],
    id       = [1, 2, 1, 2],
    value    = [10, 20, 30, 40],
)
END

  Generate_testfile(code_lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_name")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  const expected_prompt = 'julia> '
  WaitForPrompt(expected_prompt)

  var bufnr = term_list()[0]
  var lastline = LastNonEmptyLine(bufnr)
  assert_match(expected_prompt, lastline)

  # ReplicaSendCell
  cursor(1, 1)
  # var expected_lines = [14, 32, 64]
  var expected_lines = [14, 32, 64]

  for line in expected_lines
    exe "ReplicaSendCell"
    WaitForPrompt(expected_prompt)
    WaitForJuliaSymbol("DataFrame")
    lastline = LastNonEmptyLine(bufnr)
    # Check that in the editor you end up in the correct line
    assert_equal(line, line('.'))
  endfor

  # ReplicaSendLine
  cursor(17, 1)
  expected_lines = [18, 19]

  for line in expected_lines
    exe "ReplicaSendLine"
    WaitForPrompt(expected_prompt)
    lastline = LastNonEmptyLine(bufnr)
    # Check that in the editor you end up in the correct line
    assert_equal(line, line('.'))
  endfor

  # Double Toggle
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(1, winnr('$')))
  WaitForAssert(() => assert_true(bufexists('JULIA')))
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))
  WaitForAssert(() => assert_true(bufexists('JULIA')))

  # Remove cells
  exe "ReplicaRemoveCells"
  WaitForAssert(() => assert_equal(search(g:replica_cells_delimiters.python, 'cnw'), 0))

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
  WaitForAssert(() => assert_false(bufexists('JULIA')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  if !empty(v:errors)
    echoerr "Test failed!"
  endif

  :%bw!
  Cleanup_testfile(src_name)
enddef


def g:Test_variable_explorer_basic()
  messages clear

  const src_name = 'testfile.jl'
  const code_lines =<< trim END
      # Scalar
      FOO="hello world"
      _VIM_USER_VARS+=("FOO")

      # Array
      BAR=(a b c)
      _VIM_USER_VARS+=("BAR")

      # Nested associative array
      declare -A COMPLEX=( ['a']=1 ['b']=2 )
      _VIM_USER_VARS+=("COMPLEX")

      declare -A BAZ=( ['a']='ciao' ['b']='mare' )
      _VIM_USER_VARS+=("BAZ")

      # Float
      declare -F PI=3.14159
      _VIM_USER_VARS+=("PI")

      # Color / string style (like you had for prompt colors)
      COLOR_DIR="%F{197}"
      _VIM_USER_VARS+=("COLOR_DIR")
      COLOR_DEF="%f"
      _VIM_USER_VARS+=("COLOR_DEF")

      # Empty array
      EMPTY_ARRAY=()
      _VIM_USER_VARS+=("EMPTY_ARRAY")

      MY_ARRAY=(banana, lampone, cetriolo)
      _VIM_USER_VARS+=("MY_ARRAY")
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
  var term_cursor = term_getline(bufnr, term_cursor_pos[0])
  var expected_prompt = 'In\s\[2\]:\s*$'
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
  echom assert_equal(expected_variable_explorer, actual_variable_explorer)
  echom assert_equal($'Variable explorer: {buf_name}', &l:statusline)

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
  echom assert_equal(expected_variable_explorer, actual_variable_explorer)
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
  echom assert_equal(expected_variable_explorer, actual_variable_explorer)
  echom assert_equal($'Variable explorer: {buf_name}', &l:statusline)

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
  echom assert_equal(expected_variable_explorer, actual_variable_explorer)
  echom assert_equal($'Variable explorer: {buf_name}', &l:statusline)

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
