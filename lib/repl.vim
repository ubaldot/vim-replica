vim9script

# Module devoted to repl interaction

import "../lib/highlight.vim"
import "../lib/logger.vim"
import "../lib/ftcommands_mappings.vim"

var console_geometry = {}
var repl_channel: channel = null_channel
const host: string = 'localhost'
const port: string = '8765'
var msg_id = 1

export var variable_names: list<string>

export def Echoerr(msg: string)
  logger.Error(msg)
  echoerr $'[vim-replica]: {msg}'
enddef

export def Echowarn(msg: string)
  logger.Warn(msg)
  echohl WarningMsg | echom $'[vim-replica]: {msg}' | echohl None
enddef

def Repl_response_OK(resp: any): bool
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

  variable_names = []

  logger.Info('repl initialization')

  if empty(console_geometry)
    console_geometry = {
      width: g:replica_config.console_width,
      height: g:replica_config.console_height
    }
  endif


  logger.Info($"console position: '{g:replica_config.console_position}'")
  logger.Info($'console geometry: width: {console_geometry.width}, height: {console_geometry.height}')
  logger.Info($"console name: {b:console_name}")
  logger.Info($"repl_prompt: '{b:repl_prompt}'")
  logger.Info($'repl_name: {b:repl_name}')
  logger.Info($"cells_delimiter: '{b:cells_delimiter}'")
  logger.Info($"repl_options: '{b:repl_options}'")
  logger.Info($"vim inspect function: {b:vim_inspect_function('x')}")
  logger.Info($"vim whos function: {b:vim_whos_function()}")
  logger.Info($"run command: {b:run_command('x')}")
  logger.Info($"incremental prompt: '{b:incremental_prompt}'")
  logger.Info("-----------------------------------")


enddef

def ResizeConsoleWindow(console_win_id: number)

  logger.Info("resize console window")

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

# This is the actual entry point of the plugin
def ConsoleOpen()
  var console_win_id = 0
  var job_id = -1
  if !ConsoleExists()
    Init()
    logger.Info("create new console")

    var start_cmd = $"{b:repl_name} {b:repl_options}"

    # Send scripts to enable __vim_inspect() to the repl


    logger.Info($'start_cmd: {start_cmd}')

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

    # TODO: very bad hack
    # You could poll ch_open() but open-close, open-close, ...,  -> create error in the server
    term_wait(bufnr('$'), 5000)

    # Opem channel
    repl_channel = ch_open($'{host}:{port}', {mode: "lsp"})
    var channel_status = ch_status(repl_channel)

    if channel_status != 'open'
      Echoerr($'Failed to open channnel: {channel_status}')
    else
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
  setbufvar(bufnr('$'), 'repl_name', b:repl_name)
  setbufvar(bufnr('$'), 'repl_bufnr', b:repl_bufnr)
  setbufvar(bufnr('$'), 'repl_prompt', b:repl_prompt)

  setbufvar(bufnr('$'), 'vim_inspect_function', b:vim_inspect_function)
  setbufvar(bufnr('$'), 'vim_whos_function', b:vim_whos_function)
  setbufvar(bufnr('$'), 'vim_variable_names_function', b:vim_variable_names_function)

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

  var req = {}
  req.id = msg_id + 1
  req.method = 'runtime/vim_send_cell'
  req.params = {lines: getline(firstline, lastline)}
  req.params = extend(req.params, {type: "Send line(s)"})
  var resp = ch_evalexpr(repl_channel, req)
  if !Repl_response_OK(resp)
    Echoerr($'Error, code: {resp.error.code}, {resp.error.message}')
    return
  endif

  echo resp.result
  logger.Info($"sent line(s): {string(req.params.lines)}")
  # Jump to the next cell
  cursor(lastline + 1, getcurpos()[2])
enddef


export def SendCell()
  if !ConsoleExists()
    ConsoleOpen()
  endif
  # Get beginning and end of the cell
  var extremes = highlight.GetExtremes()
  var line_in = extremes[0]
  var line_out = extremes[1]

  var req = {}
  req.id = msg_id + 1
  req.method = 'runtime/vim_send_cell'
  req.params = {lines: getline(line_in, line_out)}
  req.params = extend(req.params, {type: "Send cell"})
  var resp = ch_evalexpr(repl_channel, req)
  if !Repl_response_OK(resp)
    Echoerr($'Error, code: {resp.error.code}, {resp.error.message}')
    return
  endif

  echo resp.result
  logger.Info($"sent cell: {string(req.params.lines)}")
  # Jump to the next cell
  cursor(line_out, getcurpos()[2])
enddef


export def SendFile(filename: string = '')

  if !ConsoleExists()
    ConsoleOpen()
  endif

  var lines: list<string>  = []
  if empty(filename)
    lines = getline(1, '$')
  elseif filereadable(filename)
    lines = readfile(filename)
  else
    Echoerr($'Cannot read file ''{filename}''')
    return
  endif

  var actual_filename = empty(filename) ? expand('%') : filename
  var req = {}
  req.id = msg_id + 1
  req.method = 'runtime/vim_send_cell'
  req.params = {lines: lines}
  req.params = extend(req.params, {type: $"Send file {actual_filename}"})
  var resp = ch_evalexpr(repl_channel, req)
  if !Repl_response_OK(resp)
    Echoerr($'Error, code: {resp.error.code}, {resp.error.message}')
    return
  endif
  echo resp.result
  logger.Info($"sent file: '{actual_filename}'")
enddef

# ---------------------------------------
# Functions for variable explorer
# ---------------------------------------

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

export def GetReplVariablesNames()
  logger.Info("getting variable names for complete list")
  term_sendkeys(bufnr($'^{b:console_name}$'), b:vim_variable_names_function())
  on_msg_received = On_Msg_Received.CompleteList

  logger.Info($'on_msg_received: {on_msg_received.name}')
  logger.Info($'sent: __vim_get_variables()')

  # Clean up console
  term_sendkeys(bufnr($'^{b:console_name}$'), "\<c-l>\n")
  logger.Info("sent: <c-l>\\n")
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

    resp = ch_evalexpr(repl_channel, req)
    if !Repl_response_OK(resp)
      Echoerr($'Error, code: {resp.error.code}, {resp.error.message}')
      return
    endif

    logger.Info($"Inspect {req.params.variable}: {resp.result}")

  else

    req.id = msg_id + 1
    req.method = 'runtime/vim_whos'
    req.params = {variable: ''}

    resp = ch_evalexpr(repl_channel, req)
    if !Repl_response_OK(resp)
      Echoerr($'Error, code: {resp.error.code}, {resp.error.message}')
      return
    endif

    logger.Info($"Whos: {resp.result}")
  endif

  DisplayVariable(split(resp.result, "\n"), req.params.variable)

enddef
