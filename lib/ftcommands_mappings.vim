vim9script

# Module devoted to set commands and mappings

import "../lib/repl.vim"
import "../lib/variable_explorer.vim"
import "../lib/logger.vim"

export def GetCompleteList(A: string, L: string, P: number): list<string>

  variable_explorer.variable_names = []
  logger.Info("sent completion list request")
  variable_explorer.GetReplVariablesNames()

  var counter = 0
  while empty(variable_explorer.variable_names) && counter < 10000
    sleep 5m
  endwhile

  if counter >= 10000
    repl.Echoerr('get completion time out')
    logger.Error('get completion time out')
    return []
  endif

  redraw
  logger.Info($"completion list received: {variable_explorer.variable_names}")

  var tmp = variable_explorer.variable_names
  return tmp->filter($'v:val =~ "^{A}"')
enddef

# Used only to allow utilization of GetCompleteList in unit-tests
export const funcs_dict = {
  GetCompleteList: GetCompleteList
}

#  ------------
#  Mappings
#  ------------
export def InstallMappings()
  noremap <buffer> <Plug>ReplicaConsoleToggle
        \ <ScriptCmd>repl.ConsoleToggle()<cr>
  tnoremap <buffer>  <Plug>ReplicaConsoleToggle
        \ <ScriptCmd>repl.ConsoleToggle()<cr>

  noremap <buffer> <Plug>ReplicaSendLines
        \ <ScriptCmd>repl.SendLines(line('.'), line('.'))<cr>k

  noremap <buffer>  <Plug>ReplicaSendFile
        \ <ScriptCmd>repl.SendFile()<cr>

  noremap <buffer> <Plug>ReplicaSendCell
        \ <ScriptCmd>repl.SendCell()<cr>

  if g:replica_config.use_default_mapping == true
    if !hasmapto('<Plug>ReplicaConsoleToggle') || empty(mapcheck("<F2>", "nt"))
      nnoremap <silent> <F2> <Plug>ReplicaConsoleToggle
      tnoremap <F2> <silent> <c-w><Plug>ReplicaConsoleToggle
    endif

    if !hasmapto('<Plug>ReplicaSendLines') || empty(mapcheck("<F9>", "nx"))
      nnoremap <buffer>  <silent>  <F9> <Plug>ReplicaSendLines
      xnoremap <buffer> <silent>  <F9> :ReplicaSendLines<cr>j
    endif

    if !hasmapto('<Plug>ReplicaSendFile') || empty(mapcheck("<F5>", "n"))
      nnoremap <buffer> <silent> <F5> <Plug>ReplicaSendFile
    endif

    if !hasmapto('<Plug>ReplicaSendCell') || empty(mapcheck("<c-enter>", "n"))
      nnoremap <buffer> <silent> <c-enter> <Plug>ReplicaSendCell
    endif
  endif
enddef


# -----------------------------
#  Commands
# -----------------------------
export def InstallConsoleCommands()
  if !exists(":ReplicaConsoleToggle")
    command -buffer ReplicaConsoleToggle silent repl.ConsoleToggle()
  endif

  if !exists(":ReplicaConsoleRestart" )
    command -buffer ReplicaConsoleRestart silent repl.ConsoleShutoff() |
          \ repl.ConsoleToggle()
  endif

  if !exists(":ReplicaConsoleShutoff")
    command -buffer ReplicaConsoleShutoff repl.ConsoleShutoff()
  endif

  if !exists(":ReplicaInspect")
    command -complete=customlist,GetCompleteList -nargs=? -buffer
          \ ReplicaInspect
          \ variable_explorer.VimInspect(<q-args>)
  endif
enddef

export def InstallSendCommands()
  if !exists(":ReplicaSendLines")
    command -buffer -range ReplicaSendLines
          \ silent repl.SendLines(<line1>, <line2>)
  endif

  if !exists(":ReplicaSendCell")
    command -buffer ReplicaSendCell silent repl.SendCell()
  endif

  if !exists(":ReplicaSendFile")
    command -buffer -nargs=? -complete=file ReplicaSendFile
          \ silent repl.SendFile(<f-args>)
  endif

  if !exists(":ReplicaRemoveCells")
    command -buffer ReplicaRemoveCells repl.RemoveCells()
  endif
enddef
