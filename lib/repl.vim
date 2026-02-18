vim9script

# Module devoted to repl interaction

import "../lib/highlight.vim"
import "../lib/logger.vim"
import "../lib/variable_explorer.vim"
import "../lib/ftcommands_mappings.vim"

var console_geometry = {}
var repl_channel: channel = null_channel
const host: string = 'localhost'
const port: string = '8765'
var msg_id = 1


export def Echoerr(msg: string)
  logger.Error(msg)
  throw $'[vim-replica]: {msg}'
enddef

export def Echowarn(msg: string)
  logger.Warn(msg)
  echohl WarningMsg | echom $'[vim-replica]: {msg}' | echohl None
enddef

def Repl_response_OK(resp: any): bool
    if has_key(resp, 'error')
       Echoerr($'Error, code: {resp.error.code}, {resp.error.message}')
       return false
    else
      logger.Info($'{resp.result}')
      Echowarn($'{resp.result}')
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

  variable_explorer.Init()

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


def IsFiletypeSupported(): bool
  # has_hey() maybe is more clear?
  # No, because if we are on a console it would return false.
  # Terminal buffers have no filetype.
  return !empty(getbufvar('%', "console_name"))
enddef

# This is the actual entry point of the plugin
def ConsoleOpen()
  var console_win_id = 0
  var job_id = -1
  if IsFiletypeSupported()
    if !ConsoleExists()
      Init()
      logger.Info("create new console")

      var start_cmd = $"{b:repl_name} {b:repl_options}"

      # Send scripts to enable __vim_inspect() to the repl
      variable_explorer.on_msg_received =  variable_explorer.On_Msg_Received.InitializeConsole


      logger.Info($'start_cmd: {start_cmd}')
      logger.Info($'on_msg_received action: {variable_explorer.on_msg_received.name}')

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

  else
    logger.Error($"Filetype {&filetype} not supported")
    Echoerr($"[vim-replica]: Filetype {&filetype} not supported")
  endif
enddef


def ConsoleClose()
  logger.Info("hide console")

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

  if IsFiletypeSupported()
    for ii in range(1, line('$'))
      if getline(ii) =~ $'^{b:cells_delimiter}'
        deletebufline('%', ii)
        logger.Debug($'removing line {ii}')
      endif
    endfor
    logger.Info('cells removed')
    echo "Cells removed."
  else
    logger.Warn($"filetype {&filetype} not supported!")
    Echowarn($"Filetype {&filetype} not supported!")
  endif
enddef

# ---------------------------------------
# Functions for sending stuff to the REPL
# ---------------------------------------
export def SendLines(firstline: number, lastline: number)
  if IsFiletypeSupported()
    if !ConsoleExists()
      ConsoleOpen()
    else

      var req = {}
      req.id = msg_id + 1
      req.method = 'runtime/vim_send_cell'
      req.params = {lines: getline(firstline, lastline)}
      req.params = extend(req.params, {type: "Send line(s)"})
      var resp = ch_evalexpr(repl_channel, req)
      if !Repl_response_OK(resp)
        return
      endif

      logger.Info($"sent line(s): {string(req.params.lines)}")
      # Jump to the next cell
      cursor(lastline + 1, getcurpos()[2])
    endif
  else
    logger.Warn($"filetype {&filetype} not supported!")
    Echowarn($"filetype {&filetype} not supported!")
  endif
enddef


export def SendCell()
  if IsFiletypeSupported()
    if !ConsoleExists()
      ConsoleOpen()
    else
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
        return
      endif

      logger.Info($"sent cell: {string(req.params.lines)}")
      # Jump to the next cell
      cursor(line_out, getcurpos()[2])
    endif
  else
    logger.Warn($"filetype {&filetype} not supported!")
    Echowarn($"filetype {&filetype} not supported!")
  endif
enddef


export def SendFile(filename: string = '')

  if IsFiletypeSupported()
    # If there are open terminals with different names than IPYTHON,
    # JULIA, etc. it will open its own
    if !ConsoleExists()
      ConsoleOpen()
    else
      if empty(filename)
        writefile(getline(1, '$'), g:replica_config.tmp_filepath)
        logger.Info('sent: current buffer')
      else
        writefile(readfile(filename), g:replica_config.tmp_filepath)
        logger.Info($"sent file: '{filename}'")
      endif
      term_sendkeys(bufnr($'^{b:console_name}$'),
                   $"{b:run_command(g:replica_config.tmp_filepath)}\n")
    endif
  else
    logger.Warn($"filetype {&filetype} not supported!")
    Echowarn($"filetype {&filetype} not supported!")
  endif
enddef
