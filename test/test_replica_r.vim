vim9script

# Test for the vim-replica plugin - R language

import "../plugin/replica.vim"
import "../lib/repl.vim"

import "./common.vim"
const WaitForAssert    = common.WaitForAssert
const WaitForPrompt    = common.WaitForPrompt
const LastNonEmptyLine = common.LastNonEmptyLine
const PatternCaught    = common.PatternCaught
const ReplStarted      = common.ReplStarted
const StartConsole     = common.StartConsole
const TestReport       = common.TestReport
const Generate_testfile = common.Generate_testfile
const Cleanup_testfile  = common.Cleanup_testfile

const expected_prompt    = '^>\s*'
const init_ready_pattern = 'Vim connected'

def WaitForRSymbol(symbol: string)
  # Polls until R reports the symbol as defined in .GlobalEnv.
  # R's source() is synchronous, but this guards against slow machines and
  # the later-based TCP loop firing with a slight delay.
  const buf_nr = b:console_bufnr
  const marker = '__VIM_REPLICA_READY__'
  const max_count = 50
  var counter = 0

  while counter < max_count
    term_sendkeys(buf_nr, $"cat(sprintf('{marker}:%s\\n', exists('{symbol}')))\n")
    sleep 100m
    redraw!

    if PatternCaught(buf_nr, $"{marker}:TRUE")
      break
    endif

    counter += 1
  endwhile

  if counter == max_count
    echoerr $"R symbol not ready: {symbol}"
  endif
enddef


const src_name = 'testfile.r'
const code_lines =<< trim END
# test_variables.R
# Define variables of different types for testing Vim variable inspection

# ─────────────────────────────
# Scalars
num_scalar <- 42L          # integer
float_scalar <- 3.14       # numeric
char_scalar <- "Hello R"   # character
bool_scalar <- TRUE        # logical

# ─────────────────────────────
# Vectors
num_vector <- c(1, 2, 3, 4, 5)
char_vector <- c("a", "b", "c")
bool_vector <- c(TRUE, FALSE, TRUE)

# ─────────────────────────────
# Lists
simple_list <- list(a = 1, b = "two", c = TRUE)
nested_list <- list(nums = num_vector, chars = char_vector, inner_list = simple_list)

# %% ─────────────────────────────
# Matrices
num_matrix <- matrix(1:9, nrow = 3, ncol = 3)
char_matrix <- matrix(letters[1:6], nrow = 2)

# ─────────────────────────────
# Data frames
df <- data.frame(
  id = 1:3,
  name = c("Alice", "Bob", "Charlie"),
  score = c(85.5, 92.3, 78.9),
  passed = c(TRUE, TRUE, FALSE)
)

# %% ─────────────────────────────
# Factors
gender <- factor(c("Male", "Female", "Female", "Male"))
grades <- factor(c("A", "B", "A", "C"), levels = c("A", "B", "C", "D", "F"))

# %% ─────────────────────────────
# Functions
square <- function(x) x^2
greet <- function(name) paste("Hello,", name)


# ─────────────────────────────
# End of test file
END


# Tests start here
def g:Test_R_basic()

  v:errors = []
  v:errmsg = ''
  messages clear

  if exepath('R')->empty()
    throw "Skipped: 'R' executable is not found in $PATH"
  endif

  Generate_testfile(code_lines, src_name)
  exe $"edit {src_name}"
  b:waitforprompt_nudge = true

  # Check that buffer variables are set
  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  # Start console
  if !StartConsole(expected_prompt, init_ready_pattern)
    return
  endif

  # Sometimes after TCP connect the prompt needs a nudge
  term_sendkeys(b:console_bufnr, "\n")

  # ReplicaSendCell
  cursor(1, 1)
  var expected_lines = [22, 36, 41]

  for line in expected_lines
    exe "ReplicaSendCell"
    term_sendkeys(b:console_bufnr, "\n")
    WaitForPrompt(expected_prompt)
    assert_equal(line, line('.'))
  endfor

  # ReplicaSendLine
  cursor(6, 1)
  expected_lines = [7, 8]

  for line in expected_lines
    exe "ReplicaSendLine"
    term_sendkeys(b:console_bufnr, "\n")
    WaitForPrompt(expected_prompt)
    assert_equal(line, line('.'))
  endfor

  # Double Toggle
  var lastline = LastNonEmptyLine(b:console_bufnr)
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
  if !StartConsole(expected_prompt, init_ready_pattern, "ReplicaConsoleRestart")
    return
  endif

  term_sendkeys(b:console_bufnr, "\n")

  # ReplicaSendFile
  exe "ReplicaSendFile"
  term_sendkeys(b:console_bufnr, "\n")
  WaitForPrompt(expected_prompt)
  lastline = LastNonEmptyLine(b:console_bufnr)
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_match(expected_prompt, lastline))

  # Shutoff
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('R')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  TestReport()

  :%bw!
  Cleanup_testfile(src_name)
enddef


def g:Test_R_variable_explorer_basic()
  v:errors = []
  v:errmsg = ''
  messages clear

  Generate_testfile(code_lines, src_name)
  exe $"edit {src_name}"
  b:waitforprompt_nudge = true

  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  if !StartConsole(expected_prompt, init_ready_pattern)
    return
  endif

  term_sendkeys(b:console_bufnr, "\n")

  exe "ReplicaSendFile"
  term_sendkeys(b:console_bufnr, "\n")
  WaitForPrompt(expected_prompt)
  WaitForRSymbol("greet")
  var lastline = LastNonEmptyLine(b:console_bufnr)
  WaitForAssert(() => assert_equal(2, winnr('$')))
  WaitForAssert(() => assert_match(expected_prompt, lastline))

  # -- Test scalar
  var expected_variable_explorer = ['[1] TRUE']
  var buf_name = 'bool_scalar'
  exe $"ReplicaInspect {buf_name}"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  var actual_variable_explorer = getbufline(bufnr(buf_name), 1, '$')
  assert_equal(expected_variable_explorer, actual_variable_explorer)
  assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # -- Test workspace (no argument)
  # OBS! The way %whos displays variables may change with R versions, so we
  # only check that the split window opened correctly.
  exe "ReplicaInspect"
  WaitForAssert(() => assert_equal(3, winnr('$')))
  redraw

  buf_name = 'Workspace'
  assert_equal($'Variable explorer: {buf_name}', &l:statusline)

  exe "norm \<esc>"
  WaitForAssert(() => assert_equal(2, winnr('$')))

  # Shutoff
  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('R')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  TestReport()

  :%bw!
  Cleanup_testfile(src_name)
enddef


def g:Test_R_getcompletion()
  v:errmsg = ''
  v:errors = []
  messages clear

  Generate_testfile(code_lines, src_name)
  exe $"edit {src_name}"
  b:waitforprompt_nudge = true

  assert_false(empty(getbufvar(bufnr(), "repl_start_cmd")))

  if !StartConsole(expected_prompt, init_ready_pattern)
    return
  endif

  term_sendkeys(b:console_bufnr, "\n")

  exe 'ReplicaSendFile'
  term_sendkeys(b:console_bufnr, "\n")
  WaitForPrompt(expected_prompt)
  WaitForRSymbol("greet")

  var lastline = LastNonEmptyLine(b:console_bufnr)
  assert_match(expected_prompt, lastline)

  const expected_value = [
    'bool_scalar',
    'bool_vector',
    'char_matrix',
    'char_scalar',
    'char_vector',
    'df',
    'float_scalar',
    'gender',
    'grades',
    'greet',
    'nested_list',
    'num_matrix',
    'num_scalar',
    'num_vector',
    'simple_list',
    'square'
  ]

  g:XXX = repl.funcs_dict.GetCompleteList
  const actual_value = getcompletion('', 'customlist,XXX')

  assert_equal(expected_value, actual_value)

  exe "ReplicaConsoleShutoff"
  WaitForAssert(() => assert_false(bufexists('R')))
  WaitForAssert(() => assert_equal(1, winnr('$')))

  TestReport()

  :%bw!
  Cleanup_testfile(src_name)
enddef
