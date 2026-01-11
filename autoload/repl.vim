vim9script

import "../autoload/highlight.vim"
import "../autoload/variable_inspector.vim"
import "../plugin/replica.vim"

# const replica_path = replica.replica_path

const replica_path = expand('<sfile>:h:h')

# ---------------------------------------
# State
# ---------------------------------------
#
var console_geometry = {}
var out_buf: string
var prompt_action: string
var ipython_prompt: string

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

  out_buf = ''
  prompt_action = ''
  ipython_prompt = 'In\s\[\d\+\]:\s$'
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

def HandleLine(line: string)
  echom line
  # For the variable_inspector
  if line =~ '^__VIM_PAYLOAD__' && line =~ '__END__$'

    var payload = line[len('__VIM_PAYLOAD__') : -1]
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
    if prompt_action == 'init'
      SendInitScript($"{replica_path}/python/ipython_init.py")
      prompt_action = ''
    endif
  endif
enddef

# def NormalizeStream(msg: string): string
#   # Remove terminal garbage such as ^[[09182l^M^@ and such
#   var msg_normalized = msg
#     # ->substitute('[\x0]', '', 'g')
#     # ->substitute('\r\n', '\n', 'g')
#     ->substitute('\r', '\n', 'g')
#     ->substitute('\e\[[0-9;?]*[@-~]', '', 'g')

#   # echom "msg_normalized: " .. msg_normalized
#   return msg_normalized
# enddef

def NormalizeStream(msg: string): string
  if msg =~ '\%x00'
    return msg
      # Strip ANSI escapes
      ->substitute('\e\[[0-9;?]*[@-~]', '', 'g')
      # Remove UTF-16 padding
      ->substitute('\%x00', '', 'g')
      # Windows console emits CR (UTF-16)
      ->substitute('\r', '\n', 'g')
  else
    return msg
      ->substitute('\r\n', '\n', 'g')
      ->substitute('\r', '\n', 'g')
      ->substitute('\e\[[0-9;?]*[@-~]', '', 'g')
  endif
enddef
# def ReplicaOutCb(job: channel, msg: string)
#   # 1. Normalize and accumulate
#   out_buf ..= NormalizeStream(msg)

#   echom out_buf

#   # 2. Process as long as something meaningful exists
#   while true
#   #   # ---- Payload start ----
#   #   if !s:in_payload
#   #     var idx = stridx(s:out_buf, '__VIM_PAYLOAD__')
#   #     if idx >= 0
#   #       s:out_buf = s:out_buf[idx + strlen('__VIM_PAYLOAD__') :]
#   #       s:payload_buf = ''
#   #       s:in_payload = true
#   #       continue
#   #     endif
#   #   endif

#   #   # ---- Payload end ----
#   #   if s:in_payload
#   #     var idx = stridx(s:out_buf, '__END__')
#   #     if idx >= 0
#   #       s:payload_buf ..= s:out_buf[: idx - 1]
#   #       s:out_buf = s:out_buf[idx + strlen('__END__') :]
#   #       s:in_payload = false
#   #       HandlePayload(s:payload_buf)
#   #       s:payload_buf = ''
#   #       continue
#   #     endif

#   #     # Still inside payload, consume everything
#   #     s:payload_buf ..= s:out_buf
#   #     s:out_buf = ''
#   #     break
#   #   endif

#     # ---- Prompt detection ----
#     if out_buf =~ ipython_prompt
#       HandlePromptReady()
#       break
#     endif

#     # Nothing more to process
#     break
#   endwhile
# enddef

def ReplicaOutCb(job: channel, msg: string)
  # stdout can send garbage, like
  #
  # In [1
  # ]:
  #
  # Depending on the terminal, the OS, etc.
  # We have to reconstruct the message line-by-line by capturing the actual \n

  # Accumulate and get rid of the terminal garbage
  echom "msg: " .. msg
  out_buf ..= NormalizeStream(msg)

  while true

    var new_line_idx = stridx(out_buf, "\n")
    if new_line_idx < 0
      echom "entered here!"
      break
    endif

    var line = out_buf[: new_line_idx - 1]
    out_buf = out_buf[new_line_idx + 1 :]

    echom "line: " .. line

    HandleLine(line)
  endwhile
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
