vim9script

# Vim plugin to get an outline of your scripts.
# Maintainer:	Ubaldo Tiberi
# License: BSD3-Clause
# GetLatestVimScripts: 6067 1 :AutoInstall: replica.vim

if !has('vim9script') ||  v:version < 900
  # Needs Vim version 9.0 and above
  echo "You need at least Vim 9.0"
  finish
endif

g:loaded_replica = true

const replica_path = expand('<sfile>:h:h')

# Remove the existing tnp file needed for SendCell() & friends, if it exists
if exists('g:replica_tmp_filepath') && filereadable(g:replica_tmp_filepath)
  delete(g:replica_tmp_filepath)
endif

# Deterministic filepath (so, if Vim crashes, we know where the file is)
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
g:replica_tmp_filepath = $'{data_dir}/vim_replica.tmp'

# --- logger setup -----

# File used for logging
g:replica_log_filepath = $'{data_dir}/vim_replica.log'

if !exists('g:replica_log_max_size')
   g:replica_log_max_size = 1024 * 1024 # 1 MB
endif

if !exists('g:replica_debug')
  g:replica_debug = false
endif

if g:replica_debug
  const head = [
  '',
  'Vim-replica-log:',
  $'{strftime("%d %b %Y %X")}',
  '---------------------'
  ]
  writefile(head, g:replica_log_filepath, 'a')
endif

if !exists('g:replica_log_level')
  g:replica_log_level = 'Error'
endif

# ----- repl.vim setup -----
if !exists('g:replica_console_position')
  g:replica_console_position = "L"
elseif index(["H", "J", "K", "L"], g:replica_console_position) == -1
  echoerr "[vim-replica]: 'g:replica_console_position' must be one of 'HJKL'"
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

# Dicts. Keys must be Vim filetypes
var replica_repls_default = {
  python: "ipython",
  julia: "julia",
  sh: "bash",
  zsh: "zsh"
}

var replica_console_names_default = {
  python: "IPYTHON",
  julia: "JULIA",
  sh: "SH",
  zsh: "ZSH"
}

# TODO: Not sure if you want the user to override this
var replica_run_commands_default = {
  python: (filename) => $"run -i {filename->substitute("\\", "/", "g")}",
  julia: (filename) => $'include("{filename->substitute("\\", "/", "g")}")',
  sh: (filename) => $"source {filename->substitute("\\", "/", "g")}",
  zsh: (filename) => $"source {filename->substitute("\\", "/", "g")}"
}

var replica_repl_init_scripts_default = {
  python: $"{replica_path}/languages/python/ipython_init.py",
  julia: $"{replica_path}/languages/julia/julia_init.jl",
  sh: "",
  zsh: $"{replica_path}/languages/zsh/zsh_init.sh",
}

var replica_repl_options_default = {
  python: "",
  julia: "",
  sh: "",
  zsh: ""
}

# Initially we use the following prompts to send the init script, but then we may need
# to change them with a forced prompt, because we never know how the use set their prompts,
# especially in case of zsh, bash, etc. This makes impossible to parse a
# prompt.
# For this reason, after startup we try to guess a prompt and then we
# forcibly set one that is easy to parse, e.g. __VIM_REPLICA__$
# Nevertheless, the regex used for parsing the prompt won't change.
var replica_repl_prompts_default = {
  python: '^In\s\[\d\+\]:\s$',
  julia: "^julia>\\s*$",
  sh: ".*[\$#>]\\s*$",
  zsh: ".*[\$#>]\\s*$"
}

# User is allowed to change only replica_repls and replica_cells_delimiters
if exists('g:replica_repls')
  extend(replica_repls_default, g:replica_repls, "force")
endif

if exists('g:replica_console_names')
  extend(replica_console_names_default, g:replica_console_names, "keep")
endif

if exists('g:replica_repl_options')
  extend(replica_repl_options_default, g:replica_repl_options, "force")
endif

# If a user wants to add more languages
if exists('g:replica_run_commands')
  extend(replica_run_commands_default, g:replica_run_commands, "keep")
endif

if exists('g:replica_repl_prompts')
  extend(replica_repl_prompts_default, g:replica_repl_prompts, "keep")
endif

if exists('g:replica_repl_init_scripts')
  extend(replica_repl_init_scripts_default, g:replica_repl_init_scripts, "keep")
endif

g:replica_repls = replica_repls_default
g:replica_console_names = replica_console_names_default
g:replica_repl_options = replica_repl_options_default
g:replica_run_commands = replica_run_commands_default
g:replica_repl_prompts = replica_repl_prompts_default
g:replica_repl_init_scripts = replica_repl_init_scripts_default

# TODO at the moment the term is started directly with
# repl console ... but a user may want to do something before opening the
# console. One could
# a. use b:precommand = g:replica_pre_commands[&filtype] in ft files
# b. Update ConsoleOpen() function with term_start(b:precommand .. "repl
# console ..."
# g:replica_precommands = {
#             \ "python": "source ~/pippo && ",
#             \ "julia": ""}

# ---- ftcommands_mappings.vim setup ------
if !exists('g:replica_use_default_mapping')
  g:replica_use_default_mapping = false
endif

import "../lib/ftcommands_mappings.vim"

# --- highlight setup ------
var replica_cells_delimiters_default = {
  python: "# %%",
  julia: "# %%",
  sh: "# %%",
  zsh: "# %%"
}

# If a user wants to add a new language
if exists('g:replica_cells_delimiters')
  extend(replica_cells_delimiters_default, g:replica_cells_delimiters, "keep")
endif
g:replica_cells_delimiters = replica_cells_delimiters_default

if !exists('g:replica_display_range')
  g:replica_display_range = true
endif

if !exists('g:replica_enable_highlight')
  g:replica_enable_highlight = true
endif

if !exists('g:replica_alt_highlight')
  g:replica_alt_highlight = false
endif

import "../lib/highlight.vim"

# --- variable explorer setup ----

if !exists('g:replica_display_variables')
  g:replica_display_variables = 'vsplit'
endif

# ---- set autocmds ------
# The following variable won't change during run-time
def InitBuffers()

  # -- REPL init ----
  b:repl_name = g:replica_repls[&filetype]
  b:console_name = g:replica_console_names[&filetype]
  b:repl_options = g:replica_repl_options[&filetype]
  b:run_command = g:replica_run_commands[&filetype]
  b:repl_prompt = g:replica_repl_prompts[&filetype]
  b:repl_init_script = g:replica_repl_init_scripts[&filetype]

  # Functions to poll variable_explorer data from the repl
  # Consider to make another two dictionaries as the number of languages
  # increases
  if index(['zsh'], &filetype) != -1
    # Functions in zsh, bash, etc. are called without parenthesis,
    # e.g. __vim_whos instead of __vim_whos()
    b:vim_inspect_function = (x) => $"__vim_inspect {x}\n"
    b:vim_whos_function = () => "__vim_whos\n"
  elseif &filetype ==# 'julia'
    # VimReplica is the module name of ./lib/languages/init_julia.jl
    b:vim_inspect_function = (x) => $"VimReplica.__vim_inspect(\"{x}\")\n"
    b:vim_whos_function = () => "VimReplica.__vim_whos()\n"
  else
    b:vim_inspect_function = (x) => $"__vim_inspect(\"{x}\")\n"
    b:vim_whos_function = () => "__vim_whos()\n"
  endif

  # Standard prompt for filetypes with problematic prompts like zsh
  # OBS! Secure that in the init script you actually change prompt!
  if index(['zsh'], &filetype) != -1
    b:prompt_to_be_changed = true
  else
    b:prompt_to_be_changed = false
  endif

  # Some repl have incremental prompt, like IPython: In [2]: In [3]:, etc. so
  # it may be worth to check if the prompt changes.
  # Some other repl have the same prompt, like zsh: $, so the previous prompt
  # is always the same as the current.
  b:incremental_prompt = index(['python'], &filetype) != -1 ? true : false

  # -- highlight init ----
  b:cells_delimiter = g:replica_cells_delimiters[&filetype]
  if g:replica_enable_highlight
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

augroup REPLICA_INIT_BUFFERS
  autocmd!
  for val in keys(g:replica_repls)
    exe $"autocmd FileType {val} InitBuffers()"
  endfor
augroup END

augroup REPLICA_DELETE_TMP_FILE
  autocmd VimLeave * delete(g:replica_tmp_filepath)
augroup END
