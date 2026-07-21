vim9script
# Common routines used for running the unit tests


# The WaitFor*() functions are reused from the Vim test suite.
#
# Wait for up to five seconds for "assert" to return zero.  "assert" must be a
# (lambda) function containing one assert function.  Example:
#	call WaitForAssert({-> assert_equal("dead", job_status(job)})
#
# A second argument can be used to specify a different timeout in msec.
#
# Return zero for success, one for failure (like the assert function).
export def WaitForAssert(assert: any, ...itemlist: list<number>): number
  var timeout = get(itemlist, 0, 5000)
  if WaitForCommon(null, assert, timeout) < 0
    return 1
  endif
  return 0
enddef

# Either "expr" or "assert" is not null
# Return the waiting time for success, -1 for failure.
export def WaitForCommon(Expr: any, Assert: any, timeout: number): number
  # using reltime() is more accurate, but not always available
  var slept = 0
  var success = false
  var starttime =  exists('*reltimefloat') ? reltime() : 0

  while 1
    if typename(Expr) == 'func()'
      success = Expr()
    elseif type(Assert) == v:t_func
      success = Assert() == 0
    else
      success = eval(Expr)
    endif
    if success
      return slept
    endif

    if slept >= timeout
      break
    endif
    if type(Assert) == v:t_func
      # Remove the error added by the assert function.
      remove(v:errors, -1)
    endif

    sleep 10m
    if exists('*reltimefloat')
      slept = float2nr(reltimefloat(reltime(starttime)) * 1000)
    else
      slept += 10
    endif
  endwhile

  return -1  # timed out
enddef

# Wait for up to five seconds for "expr" to become true.  "expr" can be a
# stringified expr to evaluate, or a funcref without arguments.
# Using a lambda works best.  Example:
#	call WaitFor({-> status == "ok"})
#
# A second argument can be used to specify a different timeout in msec.
#
# When successful the time slept is returned.
# When running into the timeout an exception is thrown, thus the function does
# not return.
export def WaitFor(expr: any, ...itemlist: list<number>)
  var timeout = get(itemlist, 0, 5000)
  var slept = WaitForCommon(expr, null, timeout)
  if slept < 0
    throw 'WaitFor() timed out after ' .. timeout .. ' msec'
  endif
  return slept
enddef

export def Generate_testfile(lines: list<string>, filename: string)
  writefile(lines, filename)
enddef

export def Cleanup_testfile(filename: string)
  delete(filename)
enddef

# When you read a terminal buffer with getbufline(buf_nr, 1, '$'), you get
# something like: ['bla bla', 'foo foo', '', 'bar bar', 'In [2]: ', '', '',
# '', '', '', '', '', '', '', '', '', '', '', '', '', '', ]
export def LastNonEmptyLine(buf_nr: number): string
  var lines = getbufline(buf_nr, line('w0'), '$')
  for l in reverse(lines)
    if trim(l) !=# ''
      return l
    endif
  endfor
  return ''
enddef


export def WaitForPrompt(expected: string)
  var counter = 0
  var period = 100
  const max_count = 200

  while counter < max_count
    # Flush ConPTY buffer before reading; on Windows the terminal buffer may
    # not update until redraw is triggered.
    redraw
    var lastline = LastNonEmptyLine(b:console_bufnr)
    if lastline =~# expected
      break
    endif
    exe $"sleep {period}m"
    if lastline !=# ''
      # Only count polls where the buffer had content but the wrong prompt.
      # Empty reads mean ConPTY hasn't flushed yet — not a genuine mismatch.
      counter += 1
    endif
    # Some REPLs (R) need a repeated newline to re-display their prompt after
    # cell/file execution completes. Gated by b:waitforprompt_nudge so that
    # IPython (which increments its counter on empty Enter) is never nudged.
    if get(b:, 'waitforprompt_nudge', false)
      term_sendkeys(b:console_bufnr, "\n")
    endif
  endwhile

  # Timeout reached, fail with actual last line
  if counter == max_count
    echoerr $"Prompt not found: {expected}, got: {LastNonEmptyLine(b:console_bufnr)} after waiting {counter * period} ms"
  endif
enddef


export def PatternCaught(buf_nr: number, pattern: string): bool
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

export def ReplStarted(
    console_bufnr: number,
    pattern_1: string,
    pattern_2: string): bool

  # We have to secure that
  #   A. the REPL has stared,
  #   B. Vim is connected to the server,

  var counter = 0
  var counter_max = 100
  while !(PatternCaught(console_bufnr, pattern_1)
      && PatternCaught(console_bufnr, pattern_2))
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



# vim: shiftwidth=2 softtabstop=2 noexpandtab
