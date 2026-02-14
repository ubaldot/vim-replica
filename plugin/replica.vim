vim9script

# The ultimate Vim repl
# Maintainer:	Ubaldo Tiberi
# License: BSD3-Clause

const replica_path = expand('<sfile>:h:h')

 # ----- DeprecationWarnings --------------------
def DeprecationWarnings(param: string)
  if exists(param)
    echoerr $"[vim-replica]: '{param}' is deprecated. See :h g:replica_config"
    finish
  endif
enddef

const old_config_param = ['g:replica_names', 'g:replica_kernels',
  'g:replica_use_utf16', 'g:replica_run_commands', 'g:replica_tmp_filename',
  'g:replica_alt_highlight', 'g:replica_console_width', 'g:replica_display_range',
  'g:replica_console_height', 'g:replica_python_options',
  'g:replica_cells_delimiters',
  'g:replica_console_position', 'g:replica_enable_highlight',
  'g:replica_jupyter_console_options']

for param in old_config_param
  DeprecationWarnings(param)
endfor

# ----------------------------------------------------

if !exists('g:replica_config')
  g:replica_config = {}
endif

# tmp file used for ReplicaSendCell() & friends
# The filepath is deterministic (so, if Vim crashes, we know where the file is)
def GetDataDir(): string
  if exists('$XDG_DATA_HOME')
    return $"{$XDG_DATA_HOME}/vim"
  endif

  if has('win32') || has('win64')
    return expand($"{$HOME}/vimfiles")
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

# --- encoding ----
if !exists('g:replica_config.use_utf16')
  g:replica_config.use_utf16 = has('win32') || has('win64')
endif

# --- logger setup -----
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

if !exists('g:replica_config.repl_options')
  g:replica_config.repl_options = {
      python: "",
      julia: "",
      r: "",
      sh: "",
      zsh: ""
    }
endif

# Dicts. Keys must be Vim filetypes
var repl_names = {
  python: "ipython",
  julia: "julia",
  r: "R",
  sh: "bash --noprofile --norc -i",
  zsh: "zsh -f -i"
}

var console_names = {
  python: "IPYTHON",
  julia: "JULIA",
  r: "R",
  sh: "BASH",
  zsh: "ZSH"
}

var run_commands = {
  python: (filename) => $"run -i {filename->substitute("\\", "/", "g")}",
  julia: (filename) => $'include("{filename->substitute("\\", "/", "g")}")',
  r: (filename) => $'source("{filename->substitute("\\", "/", "g")}")',
  sh: (filename) => $"source {filename->substitute("\\", "/", "g")}",
  zsh: (filename) => $"source {filename->substitute("\\", "/", "g")}"
}

var repl_init_scripts = {
  python: $"{replica_path}/languages/python/ipython_init.py",
  julia: $"{replica_path}/languages/julia/julia_init.jl",
  r: $"{replica_path}/languages/r/r_init.R",
  sh: $"{replica_path}/languages/sh/sh_init.sh",
  zsh: $"{replica_path}/languages/zsh/zsh_init.sh",
}

# Initially we use the following prompts to send the init script, but then we may need
# to change them with a forced prompt, because we never know how users set their prompts,
# especially in case of zsh, bash, etc. This makes impossible to parse a
# prompt.
# For this reason, after startup we try to guess a prompt and then we
# forcibly set one that is easy to parse, e.g.
# vim_replica>
var repl_prompts = {
  python: '^In\s\[\d\+\]:\s$',
  julia: "^julia>\\s*$",
  r: "^>\s*$",
  sh: ".*[\$#>]\\s*$",
  zsh: ".*[\$#>]\\s*$"
}

# The items of the following dicts shall match what is in ./languages scripts
var vim_inspect_functions = {
  python: (x) => $"__vim_inspect(\"{x}\")\n",
  julia: (x) => $"VimReplica.__vim_inspect(\"{x}\")\n",
  r: (x) => $".vim_inspect(\"{x}\")\n",
  sh: (x) => $"__vim_inspect {x}\n",
  zsh: (x) => $"__vim_inspect {x}\n"
}

var vim_whos_functions = {
  python: () => $"__vim_whos()\n",
  julia: () => $"VimReplica.__vim_whos()\n",
  r: () => $".vim_whos()\n",
  sh: () => "__vim_whos\n",
  zsh: () => "__vim_whos\n"
}

var vim_variable_names_functions = {
  python: () => $"__vim_variable_names()\n",
  julia: () => $"VimReplica.__vim_variable_names()\n",
  r: () => $".vim_variable_names()\n",
  sh: () => "__vim_variable_names\n",
  zsh: () => "__vim_variable_names\n"
}

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
  zsh: "# %%"
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

# --- variable explorer setup ----
if !exists('g:replica_config.force_prompt')
  g:replica_config.force_prompt = false
endif

if !exists('g:replica_config.display_variables')
  g:replica_config.display_variables = 'vsplit'
endif

def InitBuffers()

  if !has('patch-9.1.2125')
    # Needs Vim version 9.0 and above
    echoerr "[vim-replica]: You need at least Vim 9.1.2125"
    if exists('g:replica_config')
      unlet g:replica_config
    endif
    au! REPLICA_INIT_BUFFERS
    return
  endif

  g:loaded_replica = true

  # -- REPL init ----
  b:repl_name = repl_names[&filetype]
  b:console_name = console_names[&filetype]
  b:run_command = run_commands[&filetype]
  b:repl_prompt = repl_prompts[&filetype]
  b:repl_init_script = repl_init_scripts[&filetype]

  b:vim_inspect_function = vim_inspect_functions[&filetype]
  b:vim_whos_function = vim_whos_functions[&filetype]
  b:vim_variable_names_function = vim_variable_names_functions[&filetype]

  b:repl_options = exists('g:replica_config.repl_options') ? g:replica_config.repl_options[&filetype] : ''

  # Standard prompt for filetypes with problematic prompts like zsh.
  # The prompt can be changed after the first prompt after startup is
  # detected
  if index(['zsh', 'sh', 'r'], &filetype) != -1 || g:replica_config.force_prompt
    b:change_prompt_after_init = true
  else
    b:change_prompt_after_init = false
  endif

  # Some repl have incremental prompt, like IPython: In [2]: In [3]:, etc. so
  # it may be worth to check if the prompt changes.
  # Some other repl have the same prompt, like zsh: $, so the previous prompt
  # is always the same as the current.
  b:incremental_prompt = index(['python'], &filetype) != -1 ? true : false

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

  # The following exists only if we operate in debug mode
  if g:replica_config.debug
    command! -buffer -nargs=0 ReplicaLogShow exe $"edit {g:replica_config.log_filepath}"
    command! -buffer -nargs=0 ReplicaLogDelete delete(g:replica_config.log_filepath)
  endif

  # -- command and mappings init ----
  ftcommands_mappings.InstallConsoleCommands()
  ftcommands_mappings.InstallSendCommands()
  ftcommands_mappings.InstallMappings()

enddef

augroup REPLICA_INIT_BUFFERS
  autocmd!
  for val in keys(repl_names)
    # I cannot interpolate string otherwise 'r' won't be picked ->
    # concatenate strings
    exe "autocmd FileType " .. val .. " InitBuffers()"
  endfor
augroup END

augroup REPLICA_DELETE_TMP_FILE
  autocmd VimLeave * delete(g:replica_config.tmp_filepath)
augroup END
