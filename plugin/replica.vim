vim9script

# The ultimate Vim repl
# Maintainer:	Ubaldo Tiberi
# License: BSD3-Clause

export const replica_path = expand('<sfile>:h:h')->substitute("\\", "/", "g")

# ----- DeprecationWarnings --------------------
def DeprecationWarnings(param: string)
  if exists(param)
    echoerr $"[vim-replica]: '{param}' is deprecated. See :h g:replica_config"
    finish
  endif
enddef

const old_config_param = ['g:replica_names', 'g:replica_kernels',
  'g:replica_use_utf16', 'g:replica_run_scripts', 'g:replica_tmp_filename',
  'g:replica_alt_highlight', 'g:replica_console_width', 'g:replica_display_range',
  'g:replica_console_height', 'g:replica_python_options',
  'g:replica_cells_delimiters',
  'g:replica_console_position', 'g:replica_enable_highlight',
  'g:replica_jupyter_console_options']

for param in old_config_param
  DeprecationWarnings(param)
endfor

if !exists('g:replica_config')
  g:replica_config = {}
endif

# --- logger setup -----
def GetDataDir(): string
  if has('win32') || has('win64')
    return expand($"{$HOME}/vimfiles")
  endif

  if exists('$XDG_DATA_HOME')
    return $"{$XDG_DATA_HOME}/vim"
  endif

  return expand($'{$HOME}/.local/share/vim')
enddef

const data_dir = GetDataDir()

if !isdirectory(data_dir)
  mkdir(data_dir, 'p')
endif

# File used for SendCell() & friends
g:replica_config.tmp_filepath = $'{data_dir}/vim_replica.tmp'

if exists('g:replica_config.tmp_filepath')
    && filereadable(g:replica_config.tmp_filepath)
  delete(g:replica_config.tmp_filepath)
endif


# File used for logging
if !exists('g:replica_config.log_filepath')
  g:replica_config.log_filepath = $'{data_dir}/vim_replica.log'
endif

if !exists('g:replica_config.log_max_size')
  g:replica_config.log_max_size = 1024 * 1024 # 1 MB
endif

if !exists('g:replica_config.debug')
  g:replica_config.debug = false
endif

if g:replica_config.debug
  const head = [
    '',
    'Vim-replica-log:',
    $'{strftime("%d %b %Y %X")}',
    '---------------------'
  ]
  writefile(head, g:replica_config.log_filepath, 'a')
endif

if !exists('g:replica_config.log_level')
  g:replica_config.log_level = 'Error'
endif

# ----- repl.vim setup -----
if !exists('g:replica_config.console_position')
  g:replica_config.console_position = "L"
elseif index(["H", "J", "K", "L"], g:replica_config.console_position) == -1
  echoerr "[vim-replica]: 'g:replica_config.console_position' must be one of 'HJKL'"
endif

if !exists('g:replica_config.repl_options')
  g:replica_config.repl_options = {
    python: "",
    julia: "",
    r: "",
    sh: "",
    zsh: "",
    ps1: ""
  }
endif


var start_cmds = {
  python: $"ipython -i {replica_path}/languages/python/ipython_init.py",
  julia: $"julia -i {replica_path}/languages/julia/julia_init.jl",
  r: $"R --no-save --no-restore --quiet",
  sh: "bash --noprofile --norc -i",
  zsh: "zsh -f -i",
  ps1: "pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass"
}

var console_names = {
  python: "IPYTHON",
  julia: "JULIA",
  r: "R",
  sh: "BASH",
  zsh: "ZSH",
  ps1: "PWSH"
}

var run_scripts = {
  python: (filename) => $"run -i {filename->substitute("\\", "/", "g")}\n",
  julia: (filename) => $'include("{filename->substitute("\\", "/", "g")}")',
  r: (filename) => $'source("{filename->substitute("\\", "/", "g")}")',
  sh: (filename) => $"source {filename->substitute("\\", "/", "g")}",
  zsh: (filename) => $"source {filename->substitute("\\", "/", "g")}",
  ps1: (filename) => $"Invoke-Expression (Get-Content '{filename->substitute("\\", "/", "g")}' -Raw)"
}

# Filetypes that support the TCP-based variable inspector (:ReplicaInspect)
const inspect_filetypes = ['python', 'julia', 'r']

# ---- ftcommands_mappings.vim setup ------
if !exists('g:replica_config.use_default_mapping')
  g:replica_config.use_default_mapping = false
endif

import "../lib/ftcommands_mappings.vim"

# --- highlight setup ------
var cell_delimiters = {
  python: "# %%",
  julia: "# %%",
  r: "# %%",
  sh: "# %%",
  zsh: "# %%",
  ps1: "# %%"
}

if !exists('g:replica_config.display_range')
  g:replica_config.display_range = true
endif

if !exists('g:replica_config.enable_highlight')
  g:replica_config.enable_highlight = true
endif

if !exists('g:replica_config.alt_highlight')
  g:replica_config.alt_highlight = false
endif

import "../lib/highlight.vim"


if !exists('g:replica_config.display_variables')
  g:replica_config.display_variables = 'tab'
endif

# Timeout (ms) for waiting for "server running on" in the terminal buffer.
# Julia's JIT compilation of DataFrames can take 30-90 s on Windows — raise
# this if julia tests time out on slow machines.
if !exists('g:replica_config.server_startup_timeout')
  g:replica_config.server_startup_timeout = 30000
endif

# PowerShell's PSReadLine treats "\n" as a new line within the multi-line
# editor (does NOT execute), while "\r" (carriage return) is the actual
# "execute" key.  All other shells use "\n" as Enter.
var term_enters = {
  python: "\n",
  julia: "\n",
  r: "\n",
  sh: "\n",
  zsh: "\n",
  ps1: "\r"
}

def InitBuffers()

  g:loaded_replica = true

  # -- REPL init ----
  b:repl_start_cmd = start_cmds[&filetype]
  b:console_name = console_names[&filetype]
  b:run_script = run_scripts[&filetype]
  b:term_enter = term_enters[&filetype]

  b:repl_options = exists('g:replica_config.repl_options') ? g:replica_config.repl_options[&filetype] : ''

  b:supports_inspect = index(inspect_filetypes, &filetype) >= 0

  # -- highlight init ----
  b:cells_delimiter = cell_delimiters[&filetype]
  if g:replica_config.enable_highlight
    augroup highlight_cells
      autocmd! * <buffer>
      autocmd BufEnter,BufWinEnter,WinEnter,WinLeave <buffer>
            \ highlight.HighlightCell()
      autocmd CursorMoved,CursorMovedI <buffer>
            \ highlight.HighlightCell(true)
    augroup END
  endif

  # -- command and mappings init ----
  ftcommands_mappings.InstallConsoleCommands()
  ftcommands_mappings.InstallSendCommands()
  ftcommands_mappings.InstallMappings()

enddef

# The following exists only if we operate in debug mode
if g:replica_config.debug
  command! -nargs=0 ReplicaLogShow exe $"edit {g:replica_config.log_filepath}"
  command! -nargs=0 ReplicaLogDelete delete(g:replica_config.log_filepath)
endif

augroup REPLICA_INIT_BUFFERS
  autocmd!
  for val in keys(start_cmds)
    # I cannot interpolate string otherwise 'r' won't be picked ->
    # concatenate strings
    exe "autocmd FileType " .. val .. " InitBuffers()"
  endfor
augroup END

def GetInitialGeometry()

  if !exists('g:replica_config.console_width')
    if index(["H", "L"], g:replica_config.console_position) >= 0
      g:replica_config.console_width = &columns / 2
    else
      g:replica_config.console_width = &columns
    endif
  endif

  if !exists('g:replica_config.console_height')
    if index(["H", "L"], g:replica_config.console_position) >= 0
      g:replica_config.console_height = &lines
    else
      g:replica_config.console_height = &lines / 4
    endif
  endif

enddef

augroup REPLICA_GET_GEOMETRY
  # this is done for getting the initial geometry, after all the script have
  # been loaded and the window is clearly defined
  autocmd!
  autocmd VimEnter * GetInitialGeometry()
augroup END

augroup REPLICA_DELETE_TMP_FILE
  autocmd VimLeave * delete(g:replica_config.tmp_filepath)
augroup END
