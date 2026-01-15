vim9script

const replica_path = expand('<sfile>:h:h')
const ipython_prompt = '^In\s\[\d\+\]:\s$'

# For parsing the message from the terminal upon __vim_inspect() call
var collecting_payload: bool
var payload_accum: string

# To decide what to do when a prompt is ready
export enum PromptAction
  Ready,
  Initialize
endenum
export var prompt_action: PromptAction

# Accumulator for bytes coming from the terminal
export var raw_buf: string

# TODO: Fix this
var is_utf16 = true

export def Init()
  raw_buf = ''
  collecting_payload = false
  payload_accum = ''
  prompt_action = PromptAction.Ready
enddef

def SendInitScript(filename: string)
  writefile(readfile(filename), g:replica_tmp_filename, "a")
  term_sendkeys(bufnr('^' .. b:console_name .. '$'),
        \ b:run_command(g:replica_tmp_filename) .. "\n")
  echom "vim-replica interface initialized"
enddef

def DisplayVariable(decoded_value: list<string>)
    # Example: show in a scratch buffer
    vnew
    var buf = bufnr('$')
    setbufvar(buf, '&buftype', 'nofile')
    setbufvar(buf, '&swapfile', 0)
    setbufline(buf, 1, decoded_value)
enddef

def HandleLine(line: string)
  # Single line payload
  if line =~ '^__VIM_PAYLOAD__' && line =~ '__END__$'

    var payload = matchstr(line, '__VIM_PAYLOAD__\zs.\{-}\ze__END__')
    echom "payload: " .. payload
    var decoded = blob2str(base64_decode(payload))

    DisplayVariable(decoded)
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
        DisplayVariable(decoded)
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
    echom "A"
    if prompt_action == PromptAction.Initialize
      echom "B"
      SendInitScript($"{replica_path}/python/ipython_init.py")
      echom "E"
      prompt_action = PromptAction.Ready
    endif
  endif
  # Non-payload line (normal processing)
  echom "line: " .. line
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
      break
    endtry

    # Leftovers
    raw_buf = raw_buf[idx + nbytes :]

  endwhile
enddef


export def ReplicaOutCb(_: channel, msg: string)
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
      echom "tail_stripped" .. StripAnsiEscapeSequences(tail)
      HandleLine(StripAnsiEscapeSequences(tail))
      raw_buf = ''
    catch
      echom "[vim-replica]: Cannot convert prompt utf-16 string"
    endtry
  endif
enddef

export def VimInspect(variable: string = '')
  if !empty(variable)
    term_sendkeys(bufnr($'^{b:console_name}$'), $"__vim_inspect('{variable}')\n")
  else
    term_sendkeys(bufnr($'^{b:console_name}$'), "__vim_whos()\n")
  endif
enddef
