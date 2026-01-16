vim9script

import "../autoload/highlight.vim"
import "../autoload/variable_explorer.vim"

# ---------------------------------------
# State
# ---------------------------------------

var console_geometry = {}

# ---------------------------------------
# Functions for dealing with the console
# ---------------------------------------

export def Echoerr(msg: string)
  echohl ErrorMsg | echom $'[vim-replica]: {msg}' | echohl None
enddef

export def Echowarn(msg: string)
  echohl WarningMsg | echom $'[vim-replica]: {msg}' | echohl None
enddef

def Init()
  if !exists('g:replica_console_position')
    g:replica_console_position = "L"
  elseif index(["H", "J", "K", "L"], g:replica_console_position) == -1
    Echoerr("'g:replica_console_position' must be one of 'HJKL'")
  endif

  if !exists('g:replica_console_width')
    if index(["H", "L"], g:replica_console_position) >= 0
      g:replica_console_width = &columns / 2
    else
      g:replica_console_width = &columns
    endif
  endif

  if !exists('g:replica_console_height')
    if index(["H", "L"], g:replica_console_position) >= 0
      g:replica_console_height = &lines
    else
      g:replica_console_height = &lines / 4
    endif
  endif

  if empty(console_geometry)
    console_geometry = {
      width: g:replica_console_width,
      height: g:replica_console_height
    }
  endif

  # variable explorer variables init
  variable_explorer.Init()
enddef

def ResizeConsoleWindow(console_win_id: number)
  win_execute(console_win_id, 'resize ' .. console_geometry["height"])
  win_execute(console_win_id, 'vertical resize '
        \ .. console_geometry["width"])
  if index(["J", "K"], g:replica_console_position) >= 0
    win_execute(console_win_id, 'set winfixheight')
  else
    win_execute(console_win_id, 'set winfixwidth')
  endif
enddef

def SaveConsoleWindowSize(console_win_id: number)
  console_geometry["height"] = winheight(console_win_id)
  console_geometry["width"] = winwidth(console_win_id)
enddef


def ConsoleExists(): bool
  # Check if exists a console of a given filetype (i.e.calling buffer ft)
  if exists("b:console_name")
    return bufexists(bufnr($'^{b:console_name}$'))
  else
    return false
  endif
enddef


def ConsoleWinID(): list<number>
  # Return the windows ID where a console of a specific ft is displayed.
  if ConsoleExists()
    return win_findbuf(bufnr($'^{b:console_name}$'))
  else
    return []
  endif
enddef


def IsFiletypeSupported(): bool
  # Use has_hey maybe is more clear?
  # No, because if we are on a console it would return false.
  # Terminal buffers have no filetype.
  return !empty(getbufvar('%', "console_name"))
enddef


def ConsoleOpen()
  # If console does not exist, then create one,
  # otherwise, if it is hidden, just display it.
  var console_win_id = 0
  if IsFiletypeSupported()
    if !ConsoleExists()
      Init()

      var start_cmd = "python " .. g:replica_python_options ..
            \ $" -m jupyter console --kernel={b:kernel_name} "
            \ .. b:jupyter_console_options

      variable_explorer.prompt_action = variable_explorer.PromptAction.Initialize

      echo b:console_name .. " console opening..."
      setwinvar(win_getid(), 'start_cmd', start_cmd)
      win_execute(win_getid(), 'term_start(w:start_cmd,
            \ {term_name: b:console_name, out_cb: variable_explorer.ReplicaOutCb})' )
      # We give console terminal buffer b:console_name and
      # b:kernel_name variables.
      setbufvar(bufnr('$'), 'console_name', b:console_name)
      setbufvar(bufnr('$'), 'kernel_name', b:kernel_name)
      console_win_id = win_findbuf(bufnr('$'))[0]

    elseif empty(ConsoleWinID())
      win_execute(win_getid(), 'sbuffer '
            \ .. bufnr($'^{b:console_name}$'))
      console_win_id = win_findbuf(bufnr('^'
            \ .. b:console_name .. '$'))[0]
    endif

    # Set few options
    win_execute(console_win_id, 'wincmd ' .. g:replica_console_position)
    win_execute(console_win_id, 'setlocal nobuflisted winminheight
          \ winminwidth')
    # TODO: remove in newer versions
    if exists('+winfixbuf')
      win_execute(console_win_id, 'setlocal winfixbuf')
    endif
    # Set geometry
    ResizeConsoleWindow(console_win_id)
  endif
enddef


def ConsoleClose()
  # TODO Modify and make all the REPL to close from wherever you are?
  if IsFiletypeSupported()
    for win in ConsoleWinID()
      SaveConsoleWindowSize(win)
      win_execute(win, "close!")
    endfor
  endif
enddef


# TODO: implement a full screen console feature?
export def ConsoleToggle()
  if empty(ConsoleWinID())
    ConsoleOpen()
  else
    ConsoleClose()
  endif
enddef


export def ConsoleShutoff()
  if ConsoleExists()
    exe "bw! " .. bufnr($'^{b:console_name}$')
    echo $"Console {b:console_name} shutoff."
  endif
enddef


export def RemoveCells()
  if IsFiletypeSupported()
    for ii in range(1, line('$'))
      if getline(ii) =~ "^" .. b:cells_delimiter
        deletebufline('%', ii)
      endif
    endfor
    echo "Cells removed."

  else
    Echowarn("filetype not supported!")
  endif
enddef

# ---------------------------------------
# Functions for sending stuff to the REPL
# ---------------------------------------
export def SendLines(firstline: number, lastline: number)
  if IsFiletypeSupported()
    if !ConsoleExists()
      ConsoleOpen()
    endif

    # Actual implementation
    for line in getline(firstline, lastline)
      term_sendkeys(bufnr($'^{b:console_name}$'), line .. "\n")
    endfor
    # TODO: avoid the following when firstline and lastline are passed
    norm! j^
  else
    Echowarn("filetype not supported!")
  endif
enddef


# Actually sending code-cell
export def SendCell()
  if IsFiletypeSupported()
    if !ConsoleExists()
      ConsoleOpen()
    endif
    # Get beginning and end of the cell
    var extremes = highlight.GetExtremes()
    var line_in = extremes[0]
    var line_out = extremes[1]
    # Jump to the next cell
    cursor(line_out, getcurpos()[2])
    # Write tmp file
    delete(fnameescape(g:replica_tmp_filename)) # Delete tmp file if any
    writefile(getline(line_in, line_out), g:replica_tmp_filename, "a")
    term_sendkeys(bufnr($'^{b:console_name}$'),
          \ b:run_command(g:replica_tmp_filename) .. "\n")
  else
    Echowarn("filetype not supported!")
  endif
enddef


# TODO: list<string> ?
export def SendFile(filename: string)
  # TODO: too many Ex commands.
  const current_buffer = bufnr()

  if IsFiletypeSupported()
    # If there are open terminals with different names than IPYTHON,
    # JULIA, etc. it will open its own
    if !ConsoleExists()
      ConsoleOpen()
    endif
    # Write tmp file
    delete(fnameescape(g:replica_tmp_filename)) # Delete tmp file if any
    writefile(readfile(filename), g:replica_tmp_filename, "a")
    term_sendkeys(bufnr($'^{b:console_name}$'),
          \ b:run_command(g:replica_tmp_filename) .. "\n")
  else
    Echowarn("filetype not supported!")
  endif
enddef

# =========================================
#               TEST
#  =======================================
def WaitPrompt(expected_prompt: string)
  # Wait for Jupyter Console to be up and running
  const bufnr = term_list()[0]
  var term_cursor_pos = term_getcursor(bufnr)
  var term_cursor = term_getline(bufnr, term_cursor_pos[0])

  var count = 0
  const max_count = 10
  while term_cursor !~ expected_prompt && count < max_count
    redraw!
    term_cursor_pos = term_getcursor(bufnr)
    term_cursor = term_getline(bufnr, term_cursor_pos[0])
    count += 1
    sleep 1
  endwhile
enddef

def g:Test()
  message clear
  # Open the file safely
  execute 'edit ' .. fnameescape('xxx.py')
  var buf_nr = bufnr('$')
  exe ":ReplicaConsoleToggle"
  WaitPrompt('In [1]: ')
  redraw!
  exe ":ReplicaConsoleShutoff"
  exe ":Redir messages"
  exe $"bw! {buf_nr}"
enddef
