vim9script

import "../autoload/highlight.vim"

# ---------------------------------------
# State
# ---------------------------------------
#
var console_geometry = {}

# ---------------------------------------
# Functions for dealing with the console
# ---------------------------------------

def Echoerr(msg: string)
  echohl ErrorMsg | echom $'[vim-replica]: {msg}' | echohl None
enddef

def Echowarn(msg: string)
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

  console_geometry = {width: g:replica_console_width,
    height: g:replica_console_height}
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
    return bufexists(bufnr('^' .. b:console_name .. '$'))
  else
    return false
  endif
enddef

def ConsoleWinID(): list<number>
  # Return the windows ID where a console of a specific ft is displayed.
  if ConsoleExists()
    return win_findbuf(bufnr('^' .. b:console_name .. '$'))
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
      # first start
      if empty(console_geometry)
        Init()
      endif

      var start_cmd = "python " .. g:replica_python_options ..
            \ $" -m jupyter console --kernel={b:kernel_name} "
            \ .. b:jupyter_console_options
      echo b:console_name .. " console opening..."
      setwinvar(win_getid(), 'start_cmd', start_cmd)
      win_execute(win_getid(), 'term_start(w:start_cmd,
            \ {term_name: b:console_name})' )
      # We give console terminal buffer b:console_name and
      # b:kernel_name variables.
      setbufvar(bufnr('$'), 'console_name', b:console_name)
      setbufvar(bufnr('$'), 'kernel_name', b:kernel_name)
      console_win_id = win_findbuf(bufnr('$'))[0]
    elseif empty(ConsoleWinID())
      win_execute(win_getid(), 'sbuffer '
            \ .. bufnr('^' .. b:console_name .. '$'))
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
#
export def ConsoleToggle()
  if empty(ConsoleWinID())
    ConsoleOpen()
  else
    ConsoleClose()
  endif
enddef


export def ConsoleShutoff()
  if ConsoleExists()
    exe "bw! " .. bufnr('^' .. b:console_name .. '$')
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
      term_sendkeys(bufnr('^' .. b:console_name .. '$'), line .. "\n")
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
    term_sendkeys(bufnr('^' .. b:console_name .. '$'),
          \ b:run_command .. "\n")
  else
    Echowarn("filetype not supported!")
  endif
enddef



export def SendFile(...filename: list<string>)
  # TODO: too many Ex commands.
  if !empty(filename)
    exe ":edit " ..  fnameescape(filename[0])
  endif

  if IsFiletypeSupported()
    # If there are open terminals with different names than IPYTHON,
    # JULIA, etc. it will open its own
    if !ConsoleExists()
      ConsoleOpen()
    endif
    # Write tmp file
    delete(fnameescape(g:replica_tmp_filename)) # Delete tmp file if any
    writefile(getline(1, '$'), g:replica_tmp_filename, "a")
    term_sendkeys(bufnr('^' .. b:console_name .. '$'),
          \ b:run_command .. "\n")
  else
    Echowarn("filetype not supported!")
  endif

  # Remove temp buffer
  if !empty(filename)
    exe ":bprev"
    exe "bw! " .. fnameescape(filename[0])
  endif
enddef
