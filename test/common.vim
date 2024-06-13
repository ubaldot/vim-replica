vim9scrip
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


# vim: shiftwidth=2 softtabstop=2 noexpandtab
