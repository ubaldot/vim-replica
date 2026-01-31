vim9script

import "../lib/repl.vim"
import "../lib/logger.vim"


# For parsing the message from the terminal upon __vim_inspect() call
var collecting_payload: bool
var payload_accum: string
var variable_to_inspect: string

# To decide what to do when a console_prompt is ready
export enum On_Msg_Received
  Ready,
  InitializeConsole,
  DisplayVariable,
endenum

export var on_msg_received: On_Msg_Received = On_Msg_Received.Ready

# Accumulator for bytes coming from the terminal
export var raw_buf: string
var is_utf16: bool
var last_prompt: string

export def Init(teardwn: bool = false)

  raw_buf = ''
  collecting_payload = false
  payload_accum = ''
  variable_to_inspect = ''
  on_msg_received = On_Msg_Received.Ready
  last_prompt = ''

  is_utf16 = exists('g:replica_use_utf16')
    ? g:replica_use_utf16
    : has('win32') || has('win64')

  if teardwn
    logger.Info('variable explorer teardown (Init(true))')
  else
    logger.Info('variable explorer Init()')
  endif

  logger.Info($'encoding: {is_utf16 ? "utf-16" : "utf-8"}')
  logger.Debug($'raw_buf: {raw_buf}')
  logger.Debug($'collecting_payload: {collecting_payload}')
  logger.Debug($'payload_accum: {payload_accum}')
  logger.Debug($'variable_to_inspect: {variable_to_inspect}')
  logger.Debug($'on_msg_received: {on_msg_received.name}')
  logger.Debug($'last_prompt: {last_prompt}')

enddef

def SendInitScript(filename: string)
  logger.Info('SendInitScript()')
  writefile(readfile(filename), g:replica_tmp_filename)
  term_sendkeys(bufnr($'^{b:console_name}$'),
                  $"{b:run_command(g:replica_tmp_filename)}\n")
  echom "vim-replica interface initialized"
  logger.Info("vim-replica interface initialized")
enddef

def DisplayVariable(decoded_value: list<string>)
  # Example: show in a scratch buffer
  # Shutoff existing explorer for the same variable if it is still hanging
  # somewhere

  logger.Info('DisplayVariable()')


  if bufexists(variable_to_inspect)
    logger.Info("reusing existing vertical split")
    var buf = bufnr(variable_to_inspect)
    setbufvar(buf, '&modifiable', true)
    deletebufline(buf, 1, "$")
    setbufline(buf, 1, decoded_value)
    setbufvar(buf, '&modifiable', false)
  else
    # TODO: let user choose if he wants tabs or vnew
    # tabnew
    logger.Info("creating a vertical split")

    vnew
    var buf = bufnr('$')
    setbufvar(buf, '&buftype', 'nofile')
    setbufvar(buf, '&swapfile', false)

    exe $"file {variable_to_inspect}"

    setbufline(buf, 1, decoded_value)

    setbufvar(buf, '&modifiable', false)
    setbufvar(buf, '&bufhidden', 'wipe')
    setbufvar(buf, '&winfixbuf', true)
    setwinvar(win_getid(), '&statusline', $"Variable explorer: {variable_to_inspect}")

    nnoremap <buffer> <silent> <esc> <cmd>close<cr>
  endif

  logger.Info($"displayed variable value: {decoded_value}")
  # This is the end-point. We can reset all script variables for the next
  # round.
  Init(true)
enddef


def HandleLine(line: string, console_prompt: string)

  # You may have cases In [N]: In[N] on the same line
  var line_debounced = line->substitute('\(In \[\d\+\]: \)\s*\1\+', '\1', '')

  # Single line_debounced payload
  if line_debounced =~# '^__VIM_PAYLOAD__' && line_debounced =~# '__END__$'
    logger.Info($'decoding one line payload')

    var payload = matchstr(line_debounced, '__VIM_PAYLOAD__\zs.\{-}\ze__END__')
    var decoded = blob2str(base64_decode(payload))
    logger.Info("message successfully decoded")

    if on_msg_received == On_Msg_Received.DisplayVariable
      logger.Debug($'on_msg_received: {on_msg_received.name}')
      DisplayVariable(decoded)
      on_msg_received = On_Msg_Received.Ready
      logger.Debug($'on_msg_received: {on_msg_received.name}')
    endif
  endif

  # Multi-line_debounced payload
  if line_debounced =~# '^__VIM_PAYLOAD__' && line_debounced !~# '__END__$'
    logger.Info($'decoding multi-line payload')
    # strip the prefix if the first line_debounced contains it
    payload_accum ..= line_debounced->substitute('^__VIM_PAYLOAD__', '', '')
    collecting_payload = true
    return
  endif

  # Inside the payload block
  if collecting_payload && line_debounced !~# console_prompt
    # Check if this line_debounced ends the payload
    if line_debounced =~# '__END__$'
      # strip the suffix
      payload_accum ..= line_debounced->substitute('__END__$', '', '')

      # Decode final payload
      try
        var decoded = blob2str(base64_decode(payload_accum))
        logger.Info("message successfully decoded")
        if on_msg_received == On_Msg_Received.DisplayVariable
          logger.Debug($"on_msg_received: {on_msg_received.name}")
          DisplayVariable(decoded)
          on_msg_received = On_Msg_Received.Ready
          logger.Debug($"on_msg_received: {on_msg_received.name}")
        endif
      catch
        logger.Error("invalid base64 payload")
        repl.Echoerr("invalid base64 payload")
      finally
        # Reset all relevant script variables
        payload_accum = ''
        collecting_payload = false
      endtry
      return
    endif

    # No end yet, accumulate:
    payload_accum ..= line_debounced
    return
  endif

  # Prompt is ready. Do something
  if line_debounced =~# console_prompt
    if line_debounced == last_prompt
      return
    endif

    if on_msg_received == On_Msg_Received.InitializeConsole
      logger.Debug($'on_msg_received: {on_msg_received.name}')
      SendInitScript(b:repl_init_script)
      on_msg_received = On_Msg_Received.Ready
      payload_accum = ''
      logger.Info($"sending init script: {b:repl_init_script}")
      logger.Debug($'on_msg_received: {on_msg_received.name}')
    endif

    last_prompt = line_debounced
  endif

  # Non-payload line_debounced (normal processing)
  logger.Debug($"line: {line}")
  logger.Debug($"line_debounced: {line_debounced}")
  logger.Debug($"last_prompt: {last_prompt}")
  # echom $"line_debounced: {line_debounced}"
enddef


def StripAnsiEscapeSequences(msg: string): string
  # Strip ANSI escape sequences
  var tmp = msg->substitute('\e\=\[[0-9;?]*[@-~]', '', 'g')
    # Normalize CR
    ->substitute('\r\n\|\r', "\n", 'g')
    # Remove BS
    ->substitute('\%x08', '', 'g')
  return tmp
enddef

def FeedChars(bytes: string, console_prompt: string)

  raw_buf ..= bytes

  # Reconstruct lines based on when \n, \r and \n\r appear in the stdout stream
  while true
    var idx = -1
    var nbytes = -1

    logger.Debug($'is_utf16: {is_utf16}')

    # UTF-16LE case
    if is_utf16
      if len(raw_buf) < 2
        break
      endif

      var idx_cr = match(raw_buf, "\x0D\x00")
      var idx_lf = match(raw_buf, "\x0A\x00")

      if idx_cr >= 0 && idx_lf == idx_cr + 2
        idx = idx_cr
        nbytes = 4
      elseif idx_cr >= 0 && (idx_lf < 0 || idx_cr < idx_lf)
        idx = idx_cr
        nbytes = 2
      elseif idx_lf >= 0
        idx = idx_lf
        nbytes = 2
      endif
    # UTF-8 case
    else
      # TODO: Sometimes line-breaks don't happen and you may get In [1]: In [1]:
      # and therefore the regex '^In\s\[\d\+\]:\s$' cannot be used,
      # but must use a relaxed '^In\s\[\d\+\]:\s'. This branch should be
      # fixed.
      var idx_cr = match(raw_buf, "\x0D")
      var idx_lf = match(raw_buf, "\x0A")

      if idx_cr >= 0 && idx_lf == idx_cr + 1
        idx = idx_cr
        nbytes = 2
      elseif idx_cr >= 0 && (idx_lf < 0 || idx_cr < idx_lf)
        idx = idx_cr
        nbytes = 1
      elseif idx_lf >= 0
        idx = idx_lf
        nbytes = 1
      endif
    endif

    if idx < 0
      break
    endif

    var line = idx > 0 ? raw_buf[: idx - 1] : ''
    logger.Debug($'unstripped line: {line}')

    try
      var clean_line = is_utf16
        ? StripAnsiEscapeSequences(iconv(line, 'utf-16le', 'utf-8'))
        : StripAnsiEscapeSequences(line)

      HandleLine(clean_line, console_prompt)
    catch
      raw_buf = ''
      logger.Error($"Cannot convert {is_utf16 ? 'utf-16le' : 'utf-8'} string")
      repl.Echoerr($"Cannot convert {is_utf16 ? 'utf-16le' : 'utf-8'} string")
      break
    endtry

    raw_buf = raw_buf[idx + nbytes :]
  endwhile

  logger.Debug($'raw buffer: {raw_buf}')
enddef


export def ReplicaOutCb(console_prompt: string, _: channel, msg: string)
  # OBS! Issues may occur if:
  #
  #   A. A chunk from terminal match console_prompt AND
  #   B. HandleLine() do something with that
  #
  # Nevertheless, this is a very unlikely case.
  #
  # OBS! All the functions called by this callback, shall not use any b:
  # variable. This, because this function is randomly called (for example
  # when there is a screen redraw or when there is a window resize).
  # For example, if the focus goes to a buffer that has no
  # e.g. b:console_prompt, and this function is invoked, then you get an error.
  #
  # OBS! UTF-16BE encoding is not supported

  FeedChars(msg, console_prompt)

  # Handle Leftovers in the raw_buf, which is generally the prompt
  var clean_tail = is_utf16
    ? StripAnsiEscapeSequences(iconv(raw_buf, 'utf-16le', 'utf-8'))
    : StripAnsiEscapeSequences(raw_buf)

  if !empty(clean_tail) && clean_tail =~# console_prompt
    try
      HandleLine(clean_tail, console_prompt)
      raw_buf = ''
    catch
      # Reset all script variables
      Init(true)
      logger.Error($"Cannot convert prompt {is_utf16 ? 'utf-16le' : 'utf-8'} string")
      repl.Echoerr($"Cannot convert prompt {is_utf16 ? 'utf-16le' : 'utf-8'} string")
    endtry
  endif
enddef


export def VimInspect(
    variable: string = '',
    action: On_Msg_Received = On_Msg_Received.Ready
    )
  const whos_buf_name = 'Workspace'

  # TODO: attempt to have a 'live' update but 'close' close too many
  # The following relying on that the variable explorer buffer has
  # &bufhidden = 'wipe'. It closes existing variable explorers
  # if !empty(win_findbuf(bufnr(variable)))
  # var variable_explored_winid = win_findbuf(bufnr(variable))[0]
  # echom variable_explored_winid
  # win_execute(variable_explored_winid, 'close')
  # endif

  logger.Info("VimInspect()")

  # :tabonly secure that there is only one tab for variable explorer
  # tabonly
  if !empty(variable)
    var variable_single_quoted = variable->substitute('"', "'", 'g')
    term_sendkeys(bufnr($'^{b:console_name}$'), $"__vim_inspect(\"{variable_single_quoted}\")\n")
    variable_to_inspect = variable_single_quoted
    on_msg_received = On_Msg_Received.DisplayVariable

    logger.Debug($'on_msg_received: {on_msg_received.name}')
    logger.Info($"sent: __vim_inspect(\"{variable_single_quoted}\")")
  else
    term_sendkeys(bufnr($'^{b:console_name}$'), "__vim_whos()\n")
    variable_to_inspect = whos_buf_name
    on_msg_received = On_Msg_Received.DisplayVariable

    logger.Debug($'on_msg_received: {on_msg_received.name}')
    logger.Info($'sent: __vim_whos()')
  endif

  # Clean up console
  term_sendkeys(bufnr($'^{b:console_name}$'), "\<c-l>")

  logger.Info("sent: <c-l>")
enddef
