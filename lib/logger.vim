vim9script

# Usage:
#   logger.Debug('starting replica')
#   logger.Warn('fallback triggered')

enum LEVELS
  Debug,
  Info,
  Warn,
  Error,
endenum

# This is needed to link the user debug level choice to the internal LEVELS enum
const LEVELS_MAP = {
  Debug: LEVELS.Debug,
  Info:  LEVELS.Info,
  Warn:  LEVELS.Warn,
  Error: LEVELS.Error,
}

v:errmsg = ''
const user_level_str = get(g:, 'replica_log_level', 'Error')

# Check if this message should be logged
def ShouldLog(level: LEVELS): bool

  if index(keys(LEVELS_MAP), user_level_str) != -1
    return level.ordinal >= LEVELS_MAP[user_level_str].ordinal
  else
    # Disable logging in case of errors
    g:replica_debug = false
    echoerr $"[vim-replica]: Variable 'g:replica_log_level' shall be one of {string(keys(LEVELS_MAP))}. Logging disabled."
    return false
  endif

enddef

# Write a log message
def Write(level: LEVELS, msg: string)

  if !exists('g:replica_debug') || !g:replica_debug || !ShouldLog(level)
    return
  endif

  var lines = [$'{level.name}: {msg}']

  try
    writefile(lines, g:replica_log_filename, 'a')
  catch
    echoerr $'Cannot write {g:replica_log_filename}'
  endtry
enddef

export def Debug(msg: string)
  Write(LEVELS.Debug, msg)
enddef

export def Info(msg: string)
  Write(LEVELS.Info, msg)
enddef

export def Warn(msg: string)
  Write(LEVELS.Warn, msg)
enddef

export def Error(msg: string)
  if !empty(msg)
    Write(LEVELS.Error, msg)
  endif
enddef

export def BlankLine()
  try
    writefile([''], g:replica_log_filename, 'a')
  catch
    echoerr $"Cannot write {g:replica_log_filename}"
  endtry
enddef
