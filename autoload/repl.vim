vim9script

import "../autoload/highlight.vim"
import "../plugin/replica.vim"

const replica_path = expand('<sfile>:h:h')

# ---------------------------------------
# State
# ---------------------------------------

var console_geometry = {}
var ipython_prompt = '^In\s\[\d\+\]:\s$'

enum PromptAction
  Ready,
  Init
endenum
var prompt_action = PromptAction.Ready
# Bytes accumulator from terminal
var raw_buf = ''
var is_utf16 = true

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

# def WaitPrompt(expected_prompt: string)
  # Wait for Jupyter Console to be up and running
  # const bufnr = term_list()[0]
  # var term_cursor_pos = term_getcursor(bufnr)
  # var term_cursor = term_getline(bufnr, term_cursor_pos[0])

  # var count = 0
  # const max_count = 10
  # while term_cursor !~ expected_prompt && count < max_count
    # redraw!
    # term_cursor_pos = term_getcursor(bufnr)
    # term_cursor = term_getline(bufnr, term_cursor_pos[0])
    # count += 1
    # sleep 1
  # endwhile
# enddef


var collecting_payload = false
var payload_accum = ''

def HandleLine(line: string)
  # Single line payload
  if line =~ '^__VIM_PAYLOAD__' && line =~ '__END__$'
    echom "entrato"

    var payload = matchstr(line, '__VIM_PAYLOAD__\zs.\{-}\ze__END__')
    echom "payload: " .. payload
    var decoded = blob2str(base64_decode(payload))

    # Example: show in a scratch buffer
    vnew
    var buf = bufnr('$')
    setbufvar(buf, '&buftype', 'nofile')
    setbufvar(buf, '&swapfile', 0)
    setbufline(buf, 1, decoded)
  endif

  # Multi-line payload
  if line =~# '^__VIM_PAYLOAD__'
    collecting_payload = true
    payload_accum = ''

    # strip the prefix if the first line contains it
    var part = substitute(line, '^__VIM_PAYLOAD__', '', '')
    payload_accum ..= part
    return
  endif

  # Inside the payload block
  if collecting_payload
    # Check if this line ends the payload
    if line =~# '__END__$'
      # strip the suffix
      var part = substitute(line, '__END__$', '', '')
      payload_accum ..= part

      # Decode final payload
      try
        var decoded = blob2str(base64_decode(payload_accum))

        # Example: show in scratch buffer
        vnew
        var buf = bufnr('$')
        setbufvar(buf, '&buftype', 'nofile')
        setbufvar(buf, '&swapfile', 0)
        setbufline(buf, 1, decoded)
      catch
        echom "[vim-replica] ERROR: invalid base64 payload"
      endtry

      collecting_payload = false
      payload_accum = ''

      return
    endif

    # No end yet, accumulate:
    payload_accum ..= line
    return
  endif

  # Prompt is ready. Do something
  if line =~ ipython_prompt
    if prompt_action == PromptAction.Init
      SendInitScript($"{replica_path}/python/ipython_init.py")
      echom "INITIALIZED"
      prompt_action = PromptAction.Ready
    endif
  endif
  # Non-payload line (normal processing)
  echom "line: " .. line
enddef


def HandleLineOLD(line: string)
  # For the variable_inspector
  echom "line: " .. line
  if line =~ '^__VIM_PAYLOAD__' && line =! '__END__$'
    echom "entrato"

    var payload = matchstr(line, '__VIM_PAYLOAD__\zs.\{-}\ze__END__')
    echom "payload: " .. payload
    var decoded = blob2str(base64_decode(payload))

    # Example: show in a scratch buffer
    vnew
    var buf = bufnr('$')
    setbufvar(buf, '&buftype', 'nofile')
    setbufvar(buf, '&swapfile', 0)
    setbufline(buf, 1, decoded)
  endif

  # Prompt is ready. Do something
  if line =~ ipython_prompt
    if prompt_action == PromptAction.Init
      SendInitScript($"{replica_path}/python/ipython_init.py")
      echom "INITIALIZED"
      prompt_action = PromptAction.Ready
    endif
  endif

   echom $"line: {line}"
enddef

def StripAnsiEscapeSequences(msg: string): string
    # Strip ANSI escape sequences
    return msg->substitute('\e\[[0-9;?]*[@-~]', '', 'g')
enddef

def FeedChars(bytes: string)
  var line = ''
  var nbytes = is_utf16 ? 2 : 1

  # Accumulate bytes as they appear on the terminal stdout
  raw_buf ..= bytes

  while true
    # OBS! If \r\n is received, then you get an extra blank line as result.
    var idx = is_utf16
      ? match(raw_buf, "\x0D\x00\|\x0A\x00")
      : match(raw_buf, "\r\|\n")

    # echom "raw_buf: " .. raw_buf
    # echom "idx: " .. idx
    if idx < 0
      break
    elseif idx == 0
      line = ''
    else
      # Extract one full UTF-16 line (without terminator)
      line = raw_buf[: idx - 1]
    endif

    try
      if is_utf16
        HandleLine(StripAnsiEscapeSequences(iconv(line, 'utf-16le', 'utf-8')))
      else
        HandleLine(StripAnsiEscapeSequences(line))
      endif
    catch
      echom "[vim-replica]: Cannot convert utf-16 string"
      continue
    endtry

    # Leftovers
    raw_buf = raw_buf[idx + nbytes :]

  endwhile
enddef


def ReplicaOutCb(_: channel, msg: string)
  # OBS! Issues may occur if:
  #
  #   A. A chunk from terminal match ipython_prompt AND
  #   B. HandleLine() do something with that
  #
  # Nevertheless, this is a very unlikely case.

  FeedChars(msg)

  # Handle Leftovers in the raw_buf, which is generally the prompt
  var tail = is_utf16 ? iconv(raw_buf, 'utf-16le', 'utf-8') : raw_buf
  if !empty(tail) && StripAnsiEscapeSequences(tail) =~# ipython_prompt
    try
      HandleLine(StripAnsiEscapeSequences(tail))
      raw_buf = ''
    catch
      echom "[vim-replica]: Cannot convert utf-16 string"
    endtry
  endif
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

      prompt_action = PromptAction.Init

      echo b:console_name .. " console opening..."
      setwinvar(win_getid(), 'start_cmd', start_cmd)
      win_execute(win_getid(), 'term_start(w:start_cmd,
            \ {term_name: b:console_name, out_cb: ReplicaOutCb})' )
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
    echom getline(1, 5)
    term_sendkeys(bufnr('^' .. b:console_name .. '$'),
          \ b:run_command .. "\n")
  else
    Echowarn("filetype not supported!")
  endif
enddef


def SendInitScript(filename: string)
  const current_buffer = bufnr()
  exe ":edit " ..  fnameescape(filename)
  delete(fnameescape(g:replica_tmp_filename)) # Delete tmp file if any
  writefile(getline(1, '$'), g:replica_tmp_filename, "a")
  echom getline(1, 5)
  term_sendkeys(bufnr('^' .. b:console_name .. '$'),
        \ b:run_command .. "\n")
  exe ":bprev"
  exe "bw! " .. fnameescape(filename)
  exe $"buffer {current_buffer}"
  echom "Init script sent!"
enddef

export def SendFile(...filename: list<string>)
  # TODO: too many Ex commands.
  const current_buffer = bufnr()
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
    exe $"buffer {current_buffer}"
  endif
enddef

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
