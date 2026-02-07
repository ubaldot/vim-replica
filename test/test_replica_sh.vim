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

def WaitForPrompt(expected_prompt: string)
  const buf_nr = term_list()[0]
  var counter = 0
  const max_count = 50 * 2  # 20*(2*50ms) = 2 seconds max
  var line = ''

  while counter < max_count
    line = LastNonEmptyLine(buf_nr)
    if line =~# expected_prompt
      # Expected prompt appeared, return immediately
      break
    endif
    sleep 50m
    counter += 1
  endwhile

  # Timeout reached, fail with actual last line
  if counter == max_count
    throw $"Prompt not found: {expected_prompt}, got: {line} after waiting {counter * 50} ms"
  endif
enddef

# When you read a terminal buffer with getbufline(buf_nr, 1, '$'), you get
# something like: ['bla bla', 'foo foo', '', 'bar bar', 'In [2]: ', '', '',
# '', '', '', '', '', '', '', '', '', '', '', '', '', '', ]
def LastNonEmptyLine(buf_nr: number): string
  var lines = getbufline(buf_nr, 1, '$')
  for l in reverse(lines)
    if trim(l) !=# ''
      return l
    endif
  endfor
  return ''
enddef

def IsSymbolFound(buf_nr: number, symbol: string): bool
  # Found a symbol in a chunk of lines, e.g.  in
  #
  #   julia> foo bar
  #   symbol
  #
  #   julia>
  #
  var lines = getbufline(buf_nr, 1, '$')
  return index(lines, symbol) != -1 ? true : false
enddef

def WaitForJuliaSymbol(symbol: string)
  # The symbol is not necessarily the last line, because you are not reading
  # the buffer continuously, but every N seconds. Hence, in N seconds you can
  # have the following situation in the repl:
  #
  #   julia> foo bar
  #   pippo
  #
  #   julia>
  #
  # If now you read the last line, it is 'julia>'.
  #
  # The last line is generally the prompt.
  const buf_nr = term_list()[0]
  const marker = '__VIM_REPLICA_READY__'
  const max_count = 20
  var counter = 0
  var line = ''

  while counter < max_count
    term_sendkeys(
      buf_nr,
      $"println(\"{marker}:\", isdefined(Main, :{symbol}))\n"
    )
    sleep 200m
    redraw!

    if IsSymbolFound(buf_nr, $"{marker}:true")
      break
    endif

    counter += 1
  endwhile

  if counter == max_count
    throw $"Julia symbol not ready: {symbol}"
  endif
enddef

# Tests start here
def g:Test_sh_basic()

  if exepath('bash')->empty()
    throw "Skipped: 'bash' executable is not found in $PATH"
  endif

  v:errors = []
  messages clear

  const src_name = 'testfile.sh'
  const code_lines =<< trim END
_VIM_USER_VARS=()

# ─────────────────────────────
# Portable types

FOO="Hello"
_VIM_USER_VARS+=("FOO")

BAR=42
_VIM_USER_VARS+=("BAR")

ARR=("apple" "banana" "cherry")
_VIM_USER_VARS+=("ARR")

# %% ─────────────────────────────
# Shell-specific types

if [ -n "${BASH_VERSION:-}" ]; then
    # Bash associative array
    declare -A MAP=(
        [name]="bash"
        [type]="assoc"
    )
    _VIM_USER_VARS+=("MAP")

elif [ -n "${ZSH_VERSION:-}" ]; then
    # Zsh associative array
    typeset -A MAP
    MAP=(
        name zsh
        type assoc
    )
    _VIM_USER_VARS+=("MAP")
fi
END

  Generate_testfile(code_lines, src_name)
  exe $"edit {src_name}"

  # Check that the buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_name")))

  # Start console
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  const expected_prompt = 'vim_replica> '
  WaitForPrompt(expected_prompt)

  var bufnr = term_list()[0]
  var lastline = LastNonEmptyLine(bufnr)
  assert_match(expected_prompt, lastline)

  # # ReplicaSendCell
  cursor(1, 1)
  var expected_lines = [15, 34]

  for line in expected_lines
    exe "ReplicaSendCell"
    WaitForPrompt(expected_prompt)
    # Check that in the editor you end up in the correct line
    assert_equal(line, line('.'))
  endfor

  # # ReplicaSendLine
  cursor(6, 1)
  expected_lines = [7, 8]

  for line in expected_lines
    exe "ReplicaSendLine"
    WaitForPrompt(expected_prompt)
    # Check that in the editor you end up in the correct line
    assert_equal(line, line('.'))
  endfor

  # # Double Toggle
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(1, winnr('$')))
  WaitForAssert(() => assert_true(bufexists('BASH')))
  exe "ReplicaConsoleToggle"
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_true(lastline =~# expected_prompt))
  WaitForAssert(() => assert_true(bufexists('BASH')))

  # Remove cells
  exe "ReplicaRemoveCells"
  WaitForAssert(() => assert_equal(search(g:replica_cells_delimiters.sh, 'cnw'), 0))

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
  WaitForAssert(() => assert_false(bufexists('BASH')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  # ---- teardown tests ----
  if !empty(v:errors) || !empty(v:errmsg)
    silent throw string(v:errors)
  else
    echom "Test passed!"
  endif

  :%bw!
  Cleanup_testfile(src_name)
enddef


# def g:Test_sh_variable_explorer_basic()
#   messages clear
#   v:errors = []

#   const src_name = 'testfile.jl'
#   const code_lines =<< trim END
# """
# Test file for vim-replica (Bash)

# Includes:
# - Simple scalar variables
# - 1D, 2D, and 3D arrays
# - DataFrames
# """

# using DataFrames
# using Dates


# # %% -----------------
# # Simple variables
# # --------------------
# a_int   = 42
# a_float = 3.14159
# a_str   = "vim-replica test"
# a_bool  = true
# a_nothing = nothing


# # --------------------
# # 1D arrays (Vectors)
# # --------------------
# vec_int = [1, 2, 3, 4, 5]
# vec_float = [0.1, 0.2, 0.3]
# vec_mixed = [1.0, 2.5, 3.75]


# # %% -----------------
# # 2D arrays (Matrices)
# # --------------------
# mat_int = [
#     1 2 3
#     4 5 6
# ]

# mat_float = [
#     0.1 0.2
#     0.3 0.4
#     0.5 0.6
# ]


# # --------------------
# # 3D arrays
# # --------------------
# arr_3d = reshape(collect(1:8), 2, 2, 2)
# # Dimensions: (2, 2, 2)
# # arr_3d[:, :, 1] = [1 3; 2 4]
# # arr_3d[:, :, 2] = [5 7; 6 8]


# # --------------------
# # DataFrames
# # --------------------
# df_simple = DataFrame(
#     A = [1, 2, 3],
#     B = [4, 5, 6],
# )

# # %%
# df_mixed = DataFrame(
#     time  = Date(2024, 1, 1):Day(1):Date(2024, 1, 4),
#     value = [0.1, 0.2, 0.3, 0.4],
#     flag  = [true, false, true, false],
# )

# df_categorical = DataFrame(
#     category = ["x", "x", "y", "y"],
#     id       = [1, 2, 1, 2],
#     value    = [10, 20, 30, 40],
# )
# END

#   Generate_testfile(code_lines, src_name)
#   exe $"edit {src_name}"

#   # Check that the buffer variables are set
#   assert_false(empty(getbufvar(bufnr(), "repl_name")))

#   # Start console
#   exe "ReplicaConsoleToggle"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

#   var bufnr = term_list()[0]
#   var term_cursor_pos = term_getcursor(bufnr)
#   var term_cursor = term_getline(bufnr, term_cursor_pos[0])
#   var expected_prompt = 'vim_replica>\s$'
#   WaitForPrompt(expected_prompt)

#   var lastline = LastNonEmptyLine(bufnr)
#   assert_match(expected_prompt, lastline)

#   # Send current buffer
#   exe "ReplicaSendFile"
#   WaitForPrompt(expected_prompt)
#   WaitForJuliaSymbol("DataFrame")

#   # -- Test float
#   var expected_variable_explorer = ['42', '']
#   var buf_name = 'a_int'
#   exe $"ReplicaInspect {buf_name}"
#   WaitForAssert(() => assert_equal(3, winnr('$')))
#   redraw

#   var actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   assert_equal(expected_variable_explorer, actual_variable_explorer)
#   assert_equal($'Variable explorer: {buf_name}', &l:statusline)

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

#   # --- test %whos
#   #  TODO: test won't pass on Windows
#   # OBS! The way %whos display variables, may change with the repl
#   # versions, so you cannot really test it reliably. At most, you can check
#   # that a split window happened

#   # exe "ReplicaInspect"
#   # WaitForAssert(() => assert_equal(3, winnr('$')))
#   # redraw

#   # buf_name = 'Workspace'
#   # echom assert_equal($'Variable explorer: {buf_name}', &l:statusline)

#   # # Test <esc> mapping
#   # exe "norm \<esc>"
#   # WaitForAssert(() => assert_equal(2, winnr('$')))

#   # -- Test array
#   expected_variable_explorer = [
#     "1\t2\t3",
#     "4\t5\t6",
#     ""
#   ]
#   buf_name = 'mat_int'
#   exe $"ReplicaInspect {buf_name}"
#   WaitForAssert(() => assert_equal(3, winnr('$')))
#   redraw

#   actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   assert_equal(expected_variable_explorer, actual_variable_explorer)
#   assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

# #   # -- Test array slice
#   expected_variable_explorer = ["1\t2\t3", ""]

#   buf_name = 'mat_int[1, :]'
#   exe $"ReplicaInspect {buf_name}"
#   WaitForAssert(() => assert_equal(3, winnr('$')))
#   redraw

#   actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   assert_equal(expected_variable_explorer, actual_variable_explorer)
#   assert_equal($'Variable explorer: {buf_name}', &l:statusline)

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

# #   # --- Test 3D array
#   expected_variable_explorer =<< trim END
# 1	3
# 2	4

# 5	7
# 6	8

# END
#   redraw
#   buf_name = 'arr_3d'
#   exe $"ReplicaInspect {buf_name}"
#   WaitForAssert(() => assert_equal(3, winnr('$')))

#   actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   assert_equal(expected_variable_explorer, actual_variable_explorer)
#   assert_equal(&l:statusline, $'Variable explorer: {buf_name}')

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

# #   # -- Test DataFrame
#   expected_variable_explorer =<< END
# 4×3 DataFrame
#  Row │ time        value    flag
#      │ Date        Float64  Bool
# ─────┼────────────────────────────
#    1 │ 2024-01-01      0.1   true
#    2 │ 2024-01-02      0.2  false
#    3 │ 2024-01-03      0.3   true
#    4 │ 2024-01-04      0.4  false

# END

#   buf_name = 'df_mixed'
#   exe $"ReplicaInspect {buf_name}"
#   WaitForAssert(() => assert_equal(3, winnr('$')))

#   actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   assert_equal(expected_variable_explorer, actual_variable_explorer)
#   assert_equal($'Variable explorer: {buf_name}', &l:statusline)

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

#   # -- Test DataFrame slice
#   expected_variable_explorer =<< END
# true	false	true	false

# END

#   buf_name = "df_mixed.flag"
#   exe $"ReplicaInspect {buf_name}"
#   WaitForAssert(() => assert_equal(3, winnr('$')))
#   redraw

#   actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
#   assert_equal(expected_variable_explorer, actual_variable_explorer)
#   assert_equal($'Variable explorer: {buf_name}', &l:statusline)

#   # Test <esc> mapping
#   exe "norm \<esc>"
#   WaitForAssert(() => assert_equal(2, winnr('$')))

#   # Shutoff
#   exe "ReplicaConsoleShutoff"
#   WaitForAssert(() => assert_false(bufexists('BASH')))
#   WaitForAssert(() => assert_equal(1, winnr('$')))

#   if !empty(v:errors)
#     echoerr "Test failed!"
#   else
#     echom "Test passed!"
#   endif

#   # :%bw!
#   # Cleanup_testfile(src_name)
# enddef
