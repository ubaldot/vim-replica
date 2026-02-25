vim9script

# Module devoted to repl interaction

import "../lib/highlight.vim"
import "../lib/logger.vim"
import "../lib/ftcommands_mappings.vim"

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
  var job_id = -1
  if !ConsoleExists()
    Init()
    logger.Info("create new console")

    var start_cmd = $"{b:repl_start_cmd} {b:repl_options}"

    # Send scripts to enable __vim_inspect() to the repl
    logger.Info($'start_cmd: {start_cmd}')

    # ===============================================
    #            REPL & Server start
    # ===============================================
    try
      job_id = term_start(start_cmd,
        {term_name: b:console_name})

      if job_id <= 0
        Echoerr($'Failed to start terminal: {start_cmd}')
        logger.Error($'Failed to run {start_cmd}')
        return
      endif


    catch
      Echoerr($'Failed to run {start_cmd}')
      logger.Error($'Failed to run {start_cmd}')
      return
    endtry

    # =============================================
    #  Wait for server before opening a channel
    # =============================================
    # You could poll ch_open() but open-close, open-close, ...,  -> create error in the server
    # Using a while loop with a sleep won't work either
    #
    # The only way is to see when the server us running, and then we can open
    # the channel. We check the string "server running on" but we have to be
    # sure that the scripts in ./languages/ explicitly print "server running
    # on" string

    const server_available_msg = "server running on"
    var counter = 0
    const counter_max = 40
    while !PatternCaught(bufnr('$'), server_available_msg) && counter < counter_max
      sleep 200m
      redraw
      counter += 1
    endwhile

    if counter == counter_max
      Echoerr($'Failed to run {start_cmd}: timeout')
      logger.Error($'Failed to run {start_cmd}: timeout')
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
  b:repl_bufnr = job_id

  setbufvar(bufnr('$'), 'console_name', b:console_name)
  setbufvar(bufnr('$'), 'repl_start_cmd', b:repl_start_cmd)
  setbufvar(bufnr('$'), 'repl_bufnr', b:repl_bufnr)

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
    exe "bw! " .. bufnr($'^{console_name}$')
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
    term_sendkeys(bufnr($'^{b:console_name}$'), $"{line}\n")
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
    $"{b:run_script(g:replica_config.tmp_filepath)}\n")

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
    $"{b:run_script(g:replica_config.tmp_filepath)}\n")
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
    Echoerr("Empty response from the server")
    return []
  elseif !Repl_response_OK(resp)
    Echoerr($'Error, code: {resp.error.code}, {resp.error.message}')
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
      setwinvar(win_getid(), '&statusline', $"Variable explorer: {variable_to_inspect}")
      nnoremap <buffer> <silent> <esc> <cmd>close<cr>
    elseif g:replica_config.display_variables == 'vsplit'
      vnew
      setwinvar(win_getid(), '&statusline', $"Variable explorer: {variable_to_inspect}")
      nnoremap <buffer> <silent> <esc> <cmd>close<cr>
    elseif g:replica_config.display_variables == 'tab'
      tabnew
      setwinvar(win_getid(), '&statusline', $"Variable explorer: {variable_to_inspect}")
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
