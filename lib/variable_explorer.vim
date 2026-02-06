vim9script

# This function read stream from the terminal stdout and reconstruct lines by
# accumulating bytes into 'raw_buf' and by cutting at \n, \r or \r\n.
#
# Once a line is reconstructed, all the junk bytes (e.g. ANSI escape,
# sequences) are stripped out and the line is further cleaned, debounced,
# etc. and then it is processed. Lines to react on are base64 payloads
# delimited by the sentinels __VIM_PAYLOAD__ and __END__ and repl prompts.

import "../lib/repl.vim"
import "../lib/logger.vim"

# For parsing the message from the terminal upon __vim_inspect() call
var collecting_payload: bool
var payload_accum: string
var collecting_error_msg: bool
var variable_to_inspect: string

# OBS! universal_prompt shall be the same in the language initialization scripts
var universal_prompt: string
var repl_prompt: string
var incremental_prompt: bool
var prompt_to_be_changed: bool
var repl_init_script: string
var last_prompt: string

# TODO: use appropriate type
# To decide what to do when a console prompt is ready
# Startup sequence: Ready → InitializeConsole → ChangePrompt (optional) → Ready
# Operational sequence: Ready → DisplayVariable → Ready
export enum On_Msg_Received
  Ready,
  InitializeConsole,
  ChangePrompt,
  DisplayVariable
endenum

export var on_msg_received: On_Msg_Received

# Accumulator for bytes coming from the terminal
export var raw_buf: string
var is_utf16: bool

export def Init()
  logger.Info('variable explorer script initialization')

  raw_buf = ''
  collecting_payload = false
  payload_accum = ''
  variable_to_inspect = ''
  on_msg_received = On_Msg_Received.Ready
  # OBS!
  universal_prompt = '^vim_replica> $'

  is_utf16 = exists('g:replica_use_utf16')
    ? g:replica_use_utf16
    : has('win32') || has('win64')

  # This should executed only once
  repl_prompt = b:repl_prompt
  incremental_prompt = b:incremental_prompt
  prompt_to_be_changed = b:prompt_to_be_changed
  repl_init_script = b:repl_init_script
  last_prompt = ''

  logger.Info($'encoding: {is_utf16 ? "utf-16" : "utf-8"}')
  logger.Info($'raw_buf: {raw_buf}')
  logger.Info($'collecting_payload: {collecting_payload}')
  logger.Info($'payload_accum: {payload_accum}')
  logger.Info($'variable_to_inspect: {variable_to_inspect}')
  logger.Info($'on_msg_received: {on_msg_received.name}')
  logger.Info($'last_prompt: {last_prompt}')
  logger.Info($"universal prompt: '{universal_prompt}'")
  logger.Info($"init script: '{repl_init_script}'")
  logger.Info('variable explorer script initialized')
  logger.Info("-----------------------------------")
enddef

def SendInitScript(filename: string)
  writefile(readfile(filename), g:replica_tmp_filepath)
  term_sendkeys(bufnr($'^{b:console_name}$'),
    $"{b:run_command(g:replica_tmp_filepath)}\n")
enddef

def PopupFilter(id: number, key: string): bool
  # To handle the keys when release notes popup is visible
  # Close
  if key ==# 'q' || key ==# "\<esc>"
    popup_close(id)
  # Move down
  elseif ["\<C-n>", "\<Down>", "j", "\<ScrollWheelDown>"]->index(key) != -1
    win_execute(id, "normal! \<c-e>")
  # Move up
  elseif ["\<C-p>", "\<Up>", "k", "\<ScrollWheelUp>"]->index(key) != -1
    win_execute(id, "normal! \<c-y>")
  # Jump down
  elseif key == "\<C-f>"
    win_execute(id, "normal! \<c-f>")
  # Jump up
  elseif key == "\<C-b>"
    win_execute(id, "normal! \<c-b>")
  elseif key == "G"
    win_execute(id, "normal! G")
  elseif key == "g"
    win_execute(id, "normal! gg")
  elseif key == "l"
    win_execute(id, "normal! zl")
  elseif key == "h"
    win_execute(id, "normal! zh")
  elseif key == "$"
    win_execute(id, "normal! $")
  elseif key == "0"
    win_execute(id, "normal! 0")
  else
    return false
  endif
  return true
enddef

def DisplayVariablePopup(decoded_value: list<string>)

  var opts = {
    title: $" {variable_to_inspect} ",
    pos: 'center',
    border: [1, 1, 1, 1],
    borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
    # maxheight: popup_height
    # minheight: popup_height,
    # minwidth: popup_width,
    # maxwidth: popup_width,
    filter: PopupFilter,
    scrollbar: 0,
    cursorline: 0,
    mapping: 0,
    wrap: 0,
    drag: 0,
  }

  var popup_id = popup_create(decoded_value, opts)
  win_execute(popup_id, "setlocal number")
enddef

def DisplayVariable(decoded_value: list<string>)

  logger.Info('displaying variable')

  if bufexists(variable_to_inspect)
    logger.Info($"reusing existing {g:replica_display_variables}")
    var buf = bufnr(variable_to_inspect)
    setbufvar(buf, '&modifiable', true)
    deletebufline(buf, 1, "$")
    setbufline(buf, 1, decoded_value)
    setbufvar(buf, '&modifiable', false)
  else
    logger.Info($"creating a {g:replica_display_variables}")

    if g:replica_display_variables == 'split'
      new
      setwinvar(win_getid(), '&statusline', $"Variable explorer: {variable_to_inspect}")
      nnoremap <buffer> <silent> <esc> <cmd>close<cr>
    elseif g:replica_display_variables == 'vsplit'
      vnew
      setwinvar(win_getid(), '&statusline', $"Variable explorer: {variable_to_inspect}")
      nnoremap <buffer> <silent> <esc> <cmd>close<cr>
    elseif g:replica_display_variables == 'tab'
      tabnew
      setwinvar(win_getid(), '&statusline', $"Variable explorer: {variable_to_inspect}")
      nnoremap <buffer> <silent> <esc> <cmd>tabclose<cr>
    endif

    var buf = bufnr('$')
    setbufvar(buf, '&buftype', 'nofile')
    setbufvar(buf, '&swapfile', false)

    exe $"file {variable_to_inspect}"

    setbufline(buf, 1, decoded_value)

    setbufvar(buf, '&modifiable', false)
    setbufvar(buf, '&bufhidden', 'wipe')
    setbufvar(buf, '&winfixbuf', true)
  endif

  logger.Info($"displayed variable value: {decoded_value}")
enddef

def DecodeOneLinePayload(line_debounced: string): list<string>
  var payload = matchstr(line_debounced, '__VIM_PAYLOAD__\zs.\{-}\ze__END__')
  # Paylod shall always finish with a blank line, hence [: -2]
  var line_decoded = blob2str(base64_decode(payload))[: -2]
  logger.Info("one-line message successfully decoded")
  return line_decoded
enddef

# TODO: try this mechanism to be able to handle cases you receive
# __VIM_PAYLOAD__ in multi-lines like the following:
#
# __VIM_P
# AY
# LOA
# D_
# _
#
# var buffer = ''
# def FeedLine(line: string): list<string>
#   var out: list<string> = []

#   # Always append first
#   buffer ..= line

#   while true
#     if !collecting
#       # Look for START sentinel anywhere
#       var s = buffer->match('__VIM_PAYLOAD__')
#       if s < 0
#         # Keep buffer bounded (optional safety)
#         buffer = buffer[-50 :]
#         break
#       endif

#       # Drop everything before START
#       buffer = buffer[s + len('__VIM_PAYLOAD__') :]
#       collecting = true
#     else
#       # Look for END sentinel
#       var e = buffer->match('__END__')
#       if e < 0
#         break
#       endif

#       # Extract payload
#       var payload = buffer[: e - 1]
#       payload = payload->substitute('_\s*', '', 'g')

#       out->add(blob2str(base64_decode(payload)))

#       # Drop payload + END sentinel
#       buffer = buffer[e + len('__END__') :]
#       collecting = false
#     endif
#   endwhile

#   return out
# enddef

def DecodeMultiLinePayload(line_debounced: string): list<string>
  # TODO: min width of the repl must be at least 16 columns.
  # This because it is expected the string '__VIM_PAYLOAD__' to be received
  # all at once and not broken in multi-lines.
  #
  # The ideal would be to implement a FeedLines() like in the case of
  # FeedChars() and recognize the delimites __VIM_PAYLOAD__ and __END__

  if line_debounced =~# '^__VIM_PAYLOAD__'
    payload_accum ..= line_debounced->substitute('^__VIM_PAYLOAD__', '', '')
    collecting_payload = true

  elseif collecting_payload
    payload_accum ..= line_debounced

    if payload_accum =~# '__END__'
      # TODO: Strip out everything after __END__. Not nice, but what to do?
      # Time is over.
      var payload_clean = payload_accum->substitute('__END__.*$', '', '')
      payload_clean = payload_clean->substitute('_\s*', '', 'g')

      # Paylod shall always finish with a blank line, hence [: -2]
      var line_decoded = blob2str(base64_decode(payload_clean))[: -2]
      logger.Info('multi-line message successfully decoded')

      payload_accum = ''
      collecting_payload = false
      return line_decoded
    endif
  endif

  return []
enddef

def HandlePrompt(line_debounced: string)
  if line_debounced == last_prompt && incremental_prompt
    logger.Info($'Same prompt as before, no action')
  endif

  if on_msg_received == On_Msg_Received.InitializeConsole
    logger.Debug($'on_msg_received: {on_msg_received.name}')

    on_msg_received = prompt_to_be_changed
      ? On_Msg_Received.ChangePrompt
      : On_Msg_Received.Ready

    SendInitScript(repl_init_script)

    logger.Info($"sending init script: {repl_init_script}")
    logger.Debug($'on_msg_received: {on_msg_received.name}')
  elseif on_msg_received == On_Msg_Received.ChangePrompt
    logger.Info('Changing prompt')
    repl_prompt = universal_prompt
    on_msg_received = On_Msg_Received.Ready
    prompt_to_be_changed = false
  endif

  # Update last_prompt, needed for incremental prompts like in IPython
  last_prompt = line_debounced
  logger.Debug($"last_prompt: {last_prompt}")
enddef

def HandleConsoleError(line_debounced: string)

  if line_debounced =~? 'error'
    logger.Error($"Error from console: {line_debounced}")
    repl.Echoerr($"Error from console: {line_debounced}")

    collecting_error_msg = true

  elseif collecting_error_msg

    if line_debounced =~# repl_prompt
      collecting_error_msg = false
    else
      logger.Error(line_debounced)
      repl.Echoerr(line_debounced)
    endif
  endif
enddef

def HandleLine(clean_line: string)
  # Lines received can be encoded messages or prompts

  # You may have cases In [N]: In[N] on the same line
  logger.Info($"repl prompt regex: {repl_prompt}")

  # repl_prompt typically ends with '$'. Hence, prompts of the form
  # In [1]: In [1]: will not match the regex in the substitute function.
  # We have to drop the trailing $, that is why we have repl_prompt[: -2]
  var line_debounced = clean_line->substitute($'\({repl_prompt[: -2]}\)\s*\1\+', '\1', '')

  logger.Info($"clean line: {clean_line}")
  logger.Info($"line_debounced: {line_debounced}")

  # Error handling
  if line_debounced =~? 'error' || collecting_error_msg
    HandleConsoleError(line_debounced)

  # Single line_debounced payload
  elseif line_debounced =~# '^__VIM_PAYLOAD__' && line_debounced =~# '__END__$'

    logger.Info($'decoding one-line payload')
    var line_decoded = DecodeOneLinePayload(line_debounced)

    logger.Info($'on_msg_received: {on_msg_received.name}')
    if on_msg_received == On_Msg_Received.DisplayVariable
      if g:replica_display_variables == 'popup'
        DisplayVariablePopup(line_decoded)
      else
        DisplayVariable(line_decoded)
      endif
      on_msg_received = On_Msg_Received.Ready
    endif
    echo "TODO fill in autocomplete variable"

  # Multi-line debounced payload
  elseif (line_debounced =~# '^__VIM_PAYLOAD__' && line_debounced !~# '__END__$') || collecting_payload

    logger.Info($'decoding multi-line payload')
    var line_decoded = DecodeMultiLinePayload(line_debounced)

    if !empty(line_decoded) && on_msg_received == On_Msg_Received.DisplayVariable
      logger.Info($'on_msg_received: {on_msg_received.name}')
      if g:replica_display_variables == 'popup'
        DisplayVariablePopup(line_decoded)
      else
        DisplayVariable(line_decoded)
      endif
      on_msg_received = On_Msg_Received.Ready
    endif
    echo "TODO fill in autocomplete variable"

  # Prompt is ready. Do something
  elseif line_debounced =~# repl_prompt
    logger.Info($'Prompt detected: {line_debounced}')
    HandlePrompt(line_debounced)
  endif
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

def FeedChars(bytes: string)

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

      HandleLine(clean_line)
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


export def ReplicaOutCb(_: channel, msg: string)
  # OBS! Issues may occur if:
  #
  #   A. A chunk from terminal match repl_prompt regex AND
  #   B. HandleLine() do something with that
  #
  # Nevertheless, this is a very unlikely case.
  #
  # OBS! All the functions called by this callback, shall not use any b:
  # variable. This because we may jump in a new buffer (like in
  # DisplayVariable()) and all the b: are gone. Once returning from such a
  # function the caller may still try to access b: variables!
  #
  # OBS! UTF-16BE encoding is not supported

  # Using try/catch because you never know if the buffer with repl_prompt is
  # still around while executing the terminal stdout callback function
  try
    FeedChars(msg)

    # Handle Leftovers in the raw_buf, which is generally the prompt
    var clean_tail = is_utf16
      ? StripAnsiEscapeSequences(iconv(raw_buf, 'utf-16le', 'utf-8'))
      : StripAnsiEscapeSequences(raw_buf)

    if !empty(clean_tail) && clean_tail =~# repl_prompt && clean_tail !~# '\e'
      try
        HandleLine(clean_tail)
        raw_buf = ''
      catch
        logger.Error($"Cannot convert prompt {is_utf16 ? 'utf-16le' : 'utf-8'} string")
        repl.Echoerr($"Cannot convert prompt {is_utf16 ? 'utf-16le' : 'utf-8'} string")
      endtry
    endif
  catch
    logger.Error('issues found inside ReplicaOutCb')
    repl.Echoerr('issues found inside ReplicaOutCb')
  endtry
enddef


export def VimInspect(
  variable: string = '',
  action: On_Msg_Received = On_Msg_Received.Ready
  )
const whos_buf_name = 'Workspace'

logger.Info("inspecting variables")

# :tabonly secure that there is only one tab for variable explorer
# tabonly
if !empty(variable)
  var variable_single_quoted = variable->substitute('"', "'", 'g')
  term_sendkeys(bufnr($'^{b:console_name}$'), b:vim_inspect_function(variable_single_quoted))
  variable_to_inspect = variable_single_quoted
  on_msg_received = action

  logger.Info($'on_msg_received: {on_msg_received.name}')
  logger.Info($"sent: __vim_inspect(\"{variable_single_quoted}\")")
else
  term_sendkeys(bufnr($'^{b:console_name}$'), b:vim_whos_function())
  variable_to_inspect = whos_buf_name
  on_msg_received = action

  logger.Info($'on_msg_received: {on_msg_received.name}')
  logger.Info($'sent: __vim_whos()')
endif

# Capture eventual errors
if !empty(v:errmsg)
  logger.Error(v:errmsg)
endif

# Clean up console
term_sendkeys(bufnr($'^{b:console_name}$'), "\<c-l>")
logger.Info("sent: <c-l>")
enddef
