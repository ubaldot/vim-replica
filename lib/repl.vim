vim9script

# Module devoted to repl interaction

import autoload "../plugin/replica.vim"
import autoload "../lib/highlight.vim"
import autoload "../lib/logger.vim"
import autoload "../lib/ftcommands_mappings.vim"

var console_geometry = {}
export var repl_channel: channel = null_channel

# OBS this shall be the same used in scripts
const host: string = 'localhost'
const port: string = '6969'
export var msg_id = 1

export def Echoerr(msg: string)
  logger.Error(msg)
  echoerr $'[vim-replica]: {msg}'
enddef

export def Echowarn(msg: string)
  logger.Warn(msg)
  echohl WarningMsg | echom $'[vim-replica]: {msg}' | echohl None
enddef

export def Repl_response_OK(resp: any): bool
  if has_key(resp, 'error')
    return false
  else
    return true
  endif
enddef

def Init()

  # Check log file size
  if filereadable(g:replica_config.log_filepath)
      && getfsize(g:replica_config.log_filepath) > g:replica_config.log_max_size
    Echowarn($"'{g:replica_config.log_filepath}' exceeded the maximum size "
      .. $"({g:replica_config.log_max_size} bytes). "
      .. "Logging has been stopped.")
    sleep 3
    g:replica_config.debug = false
  endif

  logger.Info('repl initialization')

  if empty(console_geometry) && exists('g:replica_config')
    console_geometry = {
      width: get(g:replica_config, 'console_width', 40),
      height: get(g:replica_config, 'console_height', 20)
    }
  endif

  logger.Info($"console position: '{g:replica_config.console_position}'")
  logger.Info($'console geometry: width: {console_geometry.width}, height: {console_geometry.height}')
  logger.Info($"console name: {b:console_name}")
  logger.Info($'repl_name: {b:repl_start_cmd}')
  logger.Info($"run script: {b:run_script('x')}")
  logger.Info($"cells_delimiter: '{b:cells_delimiter}'")
  logger.Info($"repl_options: '{b:repl_options}'")
  logger.Info("-----------------------------------")


enddef

def ResizeConsoleWindow(console_win_id: number)

  logger.Info("resizing console window")

  win_execute(console_win_id, $'resize {console_geometry["height"]}')
  win_execute(console_win_id, $'vertical resize {console_geometry["width"]}')
  if index(["J", "K"], g:replica_config.console_position) >= 0
    win_execute(console_win_id, 'set winfixheight')
  else
    win_execute(console_win_id, 'set winfixwidth')
  endif
enddef

def SaveConsoleWindowSize(console_win_id: number)
  logger.Info("save console windows size")
  console_geometry["height"] = winheight(console_win_id)
  console_geometry["width"] = winwidth(console_win_id)
enddef


def ConsoleExists(): bool
  if exists("b:console_name")
    return bufexists(bufnr($"^{escape(b:console_name, '[]\.^$*~')}$"))
  else
    return false
  endif
enddef


def ConsoleWinID(): list<number>
  if ConsoleExists()
    return win_findbuf(bufnr($'^{b:console_name}$'))
  else
    return []
  endif
enddef

def PatternCaught(buf_nr: number, pattern: string): bool
  # Return true if pattern appears in the visible window. This is useful when
  # there are asynchronous jobs around and they print in the console in
  # random order
  #
  # OBS! The following will not work, so we need to take the whole buffer
  # const startline = line('w0', win_id)
  # const endline = line('w$', win_id)
  #
  const win_id = bufwinid(buf_nr)
  const startline = 1
  const endline = line('$', win_id)
  # echom "lines: " .. string(getbufline(buf_nr, startline, endline))
  return getbufline(buf_nr, startline, endline)->map($"v:val =~# '{pattern}'")->index(true) != -1
enddef

# This is the actual entry point of the plugin
def ConsoleOpen()
  # messages clear
  var console_win_id = 0
  var console_bufnr = -1

  if !ConsoleExists()
    Init()
    logger.Info("create new console")

    var start_cmd = $"{b:repl_start_cmd} {b:repl_options}"
    # Capture before term_start() switches the current buffer to the terminal.
    const supports_inspect = get(b:, 'supports_inspect', false)

    # Send scripts to enable __vim_inspect() to the repl
    logger.Info($'start_cmd: {start_cmd}')

    # ===============================================
    #            REPL & Server start
    # ===============================================
    try
      console_bufnr = term_start(start_cmd,
        {term_name: b:console_name})

      if console_bufnr <= 0
        Echoerr($'Failed to start terminal: {start_cmd}')
        logger.Error($'Failed to run {start_cmd}')
        return
      endif


    catch
      Echoerr($'Failed to run {start_cmd}')
      logger.Error($'Failed to run {start_cmd}')
      return
    endtry

    # Only for R.
    # When sourcing a script via command-line arguments, then R
    # execute the script and exit. It won't stay in interactive mode.
    # See: https://stackoverflow.com/questions/79982261/r-exe-e-source-foo-r-runs-the-script-and-immediately-close-the-repl-sess?noredirect=1#comment141115549_79982261
    #
    if getbufvar('#', 'console_name' ) ==# "R"
      var startup_delay = exists('g:replica_config.r_startup_time')
        ? g:replica_config.r_startup_time
        : 500

      exe $"sleep {startup_delay}m"

      term_sendkeys(
        console_bufnr,
        $"source('{replica.replica_path}/languages/r/r_init.R')\n"
      )

      sleep 100m
    endif


    # =============================================
    #  Wait for server before opening a channel
    # =============================================
    # Only for languages with a TCP variable-inspector server (Python, Julia,
    # R).  sh/zsh/ps1 have no server so skip this block entirely — the
    # terminal is ready as soon as term_start() returns.
    if supports_inspect
      # You could poll ch_open() but open-close, open-close, ...,  -> create error in the server
      # Using a while loop with a sleep won't work either
      #
      # The only way is to see when the server us running, and then we can open
      # the channel. We check the string "server running on" but we have to be
      # sure that the scripts in ./languages/ explicitly print "server running
      # on" string

      const server_available_msg = "server running on"
      var counter = 0
      # Derive counter_max from g:replica_config.server_startup_timeout (ms / 200 per iteration).
      # Default 60 s covers Julia's JIT compilation of DataFrames on slow Windows machines.
      const counter_max = get(g:replica_config, 'server_startup_timeout', 60000) / 200
      while !PatternCaught(bufnr('$'), server_available_msg) && counter < counter_max
        sleep 200m
        redraw
        counter += 1
      endwhile

      if counter == counter_max
        Echoerr($'Failed to run {start_cmd}: timeout')
        logger.Error($'Failed to run {start_cmd}: timeout')
        # Wipe the orphaned terminal buffer; without this the running job blocks
        # subsequent tests with E948 "Job still running".
        if console_bufnr > 0
          exe "bw! " .. console_bufnr
        endif
        return
      endif


      # ===============================================
      #             Open channel
      # ===============================================
      repl_channel = ch_open($'{host}:{port}', {mode: "lsp"})
      var channel_status = ch_status(repl_channel)

      if channel_status != 'open'
        Echoerr($'Failed to open channnel: {channel_status}')
      else
        logger.Info($'Channel status: {channel_status}, address: {host}:{port}')
        Echowarn($'Channel status: {channel_status}')

        # Probe until the server is actually processing requests, not just
        # accepting connections.  ch_open() succeeds as soon as the TCP
        # handshake completes; the request handler (e.g. R's later::later()
        # at 50 ms) may not have fired yet.  We send a no-op request and
        # retry until we receive a valid response.
        var probe_req = {id: 0, method: 'runtime/vim_variable_names'}
        var probe_counter = 0
        const probe_max = 10

        while probe_counter < probe_max
          var probe_resp = ch_evalexpr(repl_channel, probe_req, {timeout: 300})
          if !empty(probe_resp) && !has_key(probe_resp, 'error')
            break
          endif
          sleep 100m
          probe_counter += 1
        endwhile

        if probe_counter == probe_max
          Echowarn('Server readiness probe timed out; first inspect may be slow')
        else
          logger.Info($'Server ready after {probe_counter} probe(s)')
        endif
      endif
    endif

    ftcommands_mappings.InstallConsoleCommands()
    console_win_id = win_findbuf(bufnr('$'))[0]

  elseif empty(ConsoleWinID())
    logger.Info("opening existing console")
    exe 'sbuffer ' .. bufnr($"^{b:console_name}$")
    console_win_id = win_findbuf(bufnr($'^{b:console_name}$'))[0]
  endif

  exe $'wincmd {g:replica_config.console_position}'
  setlocal nobuflisted winminheight winminwidth winfixbuf

  ResizeConsoleWindow(console_win_id)

  # Cursor back to the editor
  wincmd p
  b:console_bufnr = console_bufnr

  setbufvar(bufnr('$'), 'console_name', b:console_name)
  setbufvar(bufnr('$'), 'repl_start_cmd', b:repl_start_cmd)
  setbufvar(bufnr('$'), 'console_bufnr', b:console_bufnr)

enddef


def ConsoleClose()
  logger.Info("hide console")

  # TODO Modify and make all the REPL to close from wherever you are?
  for win in ConsoleWinID()
    SaveConsoleWindowSize(win)
    win_execute(win, "close!")
  endfor
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
  logger.Info("shutoff console")

  if ConsoleExists()
    var console_name = b:console_name
    if ch_status(repl_channel) == 'open'
      ch_close(repl_channel)
      repl_channel = null_channel
    endif
    exe "bw! " .. bufnr($'^{console_name}$')
    # Poll until port 6969 is no longer accepting connections; prevents
    # port-reuse races between sequential tests, especially on Windows
    # where TIME_WAIT recycling is slower.
    var _port_counter = 0
    const _port_max = 50
    while _port_counter < _port_max
      var _probe: channel = ch_open($'{host}:{port}', {mode: "lsp", waittime: 50})
      if ch_status(_probe) != 'open'
        break
      endif
      ch_close(_probe)
      sleep 100m
      _port_counter += 1
    endwhile
    # When the console is closed the focused buffer can be of any type and
    # therefore it may not have b:console_name.
    echo $"Console {console_name} shutoff."
    logger.Info($"Console {console_name} shutoff.")

  endif
enddef


export def RemoveCells()
  logger.Info('removing cells')

  for ii in range(1, line('$'))
    if getline(ii) =~ $'^{b:cells_delimiter}'
      deletebufline('%', ii)
      logger.Debug($'removing line {ii}')
    endif
  endfor
  logger.Info('cells removed')
  echo "Cells removed."
enddef

# ---------------------------------------
# Functions for sending stuff to the REPL
# ---------------------------------------
export def SendLines(firstline: number, lastline: number)
  if !ConsoleExists()
    ConsoleOpen()
  endif

  for line in getline(firstline, lastline)
    term_sendkeys(bufnr($'^{b:console_name}$'), $"{line}{get(b:, 'term_enter', "\n")}")
    logger.Info($"sent lines: '{line}'")
  endfor
  norm! ^j
enddef


export def SendCell()
  if !ConsoleExists()
    ConsoleOpen()
  endif

  # Get beginning and end of the cell
  var extremes = highlight.GetExtremes()
  var line_in = extremes[0]
  var line_out = extremes[1]

  # Jump to the next cell
  cursor(line_out, getcurpos()[2])
  # Overwrite tmp file
  writefile(getline(line_in, line_out), g:replica_config.tmp_filepath)
  term_sendkeys(bufnr($'^{b:console_name}$'),
    $"{b:run_script(g:replica_config.tmp_filepath)}{get(b:, 'term_enter', "\n")}")

  logger.Info($"sent cell: {string(getline(line_in, line_out))}")
enddef

export def SendFile(filename: string = '')

  # If there are open terminals with different names than IPYTHON,
  # JULIA, etc. it will open its own
  if !ConsoleExists()
    ConsoleOpen()
  endif

  if empty(filename)
    writefile(getline(1, '$'), g:replica_config.tmp_filepath)
    logger.Info('sent: current buffer')
  else
    writefile(readfile(filename), g:replica_config.tmp_filepath)
    logger.Info($"sent file: '{filename}'")
  endif
  term_sendkeys(bufnr($'^{b:console_name}$'),
    $"{b:run_script(g:replica_config.tmp_filepath)}{get(b:, 'term_enter', "\n")}")
enddef

# ---------------------------------------
# Functions for variable explorer
# ---------------------------------------

export def GetCompleteList(A: string, L: string, P: number): list<string>

  logger.Info($"getting variable names for complete list")

  var req = {}
  req.id = msg_id + 1
  req.method = 'runtime/vim_variable_names'

  logger.Info($"channel_status: '{ch_status(repl_channel)}'")
  var resp = ch_evalexpr(repl_channel, req)

  if empty(resp)
    # Do NOT call Echoerr() here: echoerr aborts the function in Vim9script,
    # causing the completion function to return a number instead of a List
    # and triggering E1303.  Log silently and return an empty list.
    logger.Error("Empty response from the server")
    return []
  elseif !Repl_response_OK(resp)
    logger.Error($'Error, code: {resp.error.code}, {resp.error.message}')
    return []
  endif

  return resp.result->filter($'v:val =~ "^{A}"')
enddef

# Used only to allow utilization of GetCompleteList in unit-tests
export const funcs_dict = {
  GetCompleteList: GetCompleteList
}

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

def DisplayVariablePopup(value: list<string>, variable_to_inspect: string)

  var opts = {
    title: $" {variable_to_inspect} ",
    pos: 'center',
    border: [1, 1, 1, 1],
    borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
    minheight: 1,
    maxheight: &lines / 2,
    minwidth: 1,
    maxwidth: (&columns * 2) / 3,
    filter: PopupFilter,
    scrollbar: 0,
    cursorline: 0,
    mapping: 0,
    wrap: 0,
    drag: 0,
  }

  var popup_id = popup_create(value, opts)
  if len(value) > 1
    win_execute(popup_id, "setlocal number")
  endif
enddef

def DisplayVariable(value: list<string>, variable_to_inspect: string)

  logger.Info('displaying variable')

  const new_statusline = empty(variable_to_inspect)
    ? "Workspace"
    : $"Variable explorer: {variable_to_inspect}"

  if bufexists(variable_to_inspect)
    logger.Info($"reusing existing {g:replica_config.display_variables}")
    var buf = bufnr(variable_to_inspect)
    setbufvar(buf, '&modifiable', true)
    deletebufline(buf, 1, "$")
    setbufline(buf, 1, value)
    setbufvar(buf, '&modifiable', false)
  else
    logger.Info($"creating a {g:replica_config.display_variables}")

    if g:replica_config.display_variables == 'split'
      new
      setwinvar(win_getid(), '&statusline', new_statusline)
      nnoremap <buffer> <silent> <esc> <cmd>close<cr>
    elseif g:replica_config.display_variables == 'vsplit'
      vnew
      setwinvar(win_getid(), '&statusline', new_statusline)
      nnoremap <buffer> <silent> <esc> <cmd>close<cr>
    elseif g:replica_config.display_variables == 'tab'
      tabnew
      setwinvar(win_getid(), '&statusline', new_statusline)
      nnoremap <buffer> <silent> <esc> <cmd>tabclose<cr>
    endif

    var buf = bufnr('$')
    setbufvar(buf, '&buftype', 'nofile')
    setbufvar(buf, '&swapfile', false)

    exe $"file {variable_to_inspect}"

    setbufline(buf, 1, value)

    setbufvar(buf, '&modifiable', false)
    setbufvar(buf, '&bufhidden', 'wipe')
    setbufvar(buf, '&winfixbuf', true)
  endif

  logger.Info($"displayed variable value: {value}")
enddef

export def VimInspect(
    variable_to_inspect: string = '',
    )

  logger.Info("inspecting variables")

  var resp = {}
  var req = {}

  if !empty(variable_to_inspect)
    var variable_single_quoted = variable_to_inspect->substitute('"', "'", 'g')

    req.id = msg_id + 1
    req.method = 'runtime/vim_inspect'
    req.params = {variable: variable_single_quoted}

    logger.Info($"channel_status: '{ch_status(repl_channel)}'")
    resp = ch_evalexpr(repl_channel, req)

    if empty(resp)
      Echoerr("Empty response from the server")
      return
    elseif !Repl_response_OK(resp)
      Echoerr($'Error, code: {resp.error.code}, {resp.error.message}')
      return
    endif

    logger.Info($"Inspect {req.params.variable}: {resp.result}")

  else

    req.id = msg_id + 1
    req.method = 'runtime/vim_whos'
    req.params = {variable: ''}

    logger.Info($"channel_status: '{ch_status(repl_channel)}'")
    resp = ch_evalexpr(repl_channel, req)

    if empty(resp)
      Echoerr("Empty response from the server")
      return
    elseif !Repl_response_OK(resp)
      Echoerr($'Error, code: {resp.error.code}, {resp.error.message}')
      return
    endif


    logger.Info($"Whos: {resp.result}")
  endif

  if g:replica_config.display_variables == 'popup'
    DisplayVariablePopup(resp.result, req.params.variable)
  else
    DisplayVariable(resp.result, req.params.variable)
  endif

enddef
