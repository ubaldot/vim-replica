vim9script

import "../autoload/repl.vim"

#  ------------
#  Mappings
#  ------------
# TODO: make imap and tmap to work.
export def FtCommandsMappings()
  noremap <buffer> <Plug>ReplicaConsoleToggle
              \ <ScriptCmd>repl.ConsoleToggle()<cr>
  tnoremap <buffer>  <Plug>ReplicaConsoleToggle
              \ <ScriptCmd>repl.ConsoleToggle()<cr>

  noremap <buffer> <Plug>ReplicaSendLines
              \ <ScriptCmd>repl.SendLines(line('.'), line('.'))<cr>

  noremap <buffer>  <Plug>ReplicaSendFile
              \ <ScriptCmd>repl.SendFile()<cr>

  noremap <buffer> <Plug>ReplicaSendCell
              \ <ScriptCmd>repl.SendCell()<cr>

  if g:replica_use_default_mapping == true
      if !hasmapto('<Plug>ReplicaConsoleToggle') || empty(mapcheck("<F2>", "nt"))
          nnoremap <silent> <F2> <Plug>ReplicaConsoleToggle
          # imap <silent> <F2> <Plug>ReplicaConsoleToggle<cr>
          tnoremap <F2> <silent> <c-w><Plug>ReplicaConsoleToggle
      endif

      if !hasmapto('<Plug>ReplicaSendLines') || empty(mapcheck("<F9>", "nx"))
          nnoremap <buffer>  <silent>  <F9> <Plug>ReplicaSendLines
          # imap <silent>  <F9> <Plug>ReplicaSendLines<cr>
          xnoremap <buffer> <silent>  <F9> :ReplicaSendLines<cr>j
      endif

      if !hasmapto('<Plug>ReplicaSendFile') || empty(mapcheck("<F5>", "n"))
          nnoremap <buffer> <silent> <F5> <Plug>ReplicaSendFile
          # imap <silent> <F5> <Plug>ReplicaSendFile<cr>
      endif

      if !hasmapto('<Plug>ReplicaSendCell') || empty(mapcheck("<c-enter>", "n"))
          nnoremap <buffer> <silent> <c-enter> <Plug>ReplicaSendCell
          # imap <silent> <c-enter> <Plug>ReplicaSendCell<cr>j
      endif
  endif


# -----------------------------
#  Commands
# -----------------------------
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
