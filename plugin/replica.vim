vim9script noclear

# Vim plugin to get an outline of your scripts.
# Maintainer:	Ubaldo Tiberi
# License: BSD3-Clause
# GetLatestVimScripts: 6067 1 :AutoInstall: replica.vim

if !has('vim9script') ||  v:version < 900
    # Needs Vim version 9.0 and above
    echo "You need at least Vim 9.0"
    finish
endif

if exists('g:replica_loaded') && g:replica_loaded
    finish
endif
g:replica_loaded = true

import "../lib/ftcommands_mappings.vim"
import "../lib/highlight.vim"

# Other config parameters are handled in repl.Init()

# TODO: think if you can avoid using it as a g: variable
# Temp file used for sending cells or files
g:replica_tmp_filename = tempname()

if !exists('g:replica_display_range')
    g:replica_display_range = true
endif

if !exists('g:replica_enable_highlight')
    g:replica_enable_highlight = true
endif

if !exists('g:replica_alt_highlight')
    g:replica_alt_highlight = false
endif

if !exists('g:replica_python_options')
    g:replica_python_options = ""
endif

if !exists('g:replica_use_default_mapping')
    g:replica_use_default_mapping = false
endif

if !exists('g:replica_jupyter_console_options')
    g:replica_jupyter_console_options = {
                python: "",
                julia: ""}
endif

# Dicts. Keys must be Vim filetypes
var replica_kernels_default = {
             python: "python3",
             julia: "julia-1.8"}

var replica_console_names_default = {
            python: "IPYTHON",
            julia: "JULIA"}

var replica_cells_delimiters_default = {
            python: "# %%",
            julia: "# %%"}

var replica_run_commands_default = {
            python: "run -i " .. g:replica_tmp_filename,
            julia: 'include("' .. g:replica_tmp_filename .. '")'}

var replica_jupyter_console_options_default = {
            python: "",
            julia: ""}

# User is allowed to change only replica_kernels and replica_cells_delimiters
if exists('g:replica_kernels')
    extend(replica_kernels_default, g:replica_kernels, "force")
endif

if exists('g:replica_cells_delimiters')
    extend(replica_delimiters_default, g:replica_cells_delimiters, "force")
endif

if exists('g:replica_jupyter_console_options')
    extend(replica_jupyter_console_options_default, g:replica_jupyter_console_options, "force")
endif

g:replica_kernels = replica_kernels_default
g:replica_cells_delimiters = replica_cells_delimiters_default
g:replica_console_names = replica_console_names_default
g:replica_run_commands = replica_run_commands_default

# TODO at the moment the term is started directly with
# jupyter console ... but a user may want to do something before opening the
# console. One could
# a. use b:precommand = g:replica_pre_commands[&filtype] in ft files
# b. Update ConsoleOpen() function with term_start(b:precommand .. "jupyter
# console ..."
# g:replica_precommands = {
#             \ "python": "source ~/pippo && ",
#             \ "julia": ""}


# The following variable won't change during run-time
def SetBufferVars()
  b:kernel_name = g:replica_kernels[&filetype]
  b:console_name = g:replica_console_names[&filetype]
  b:cells_delimiter = g:replica_cells_delimiters[&filetype]
  b:jupyter_console_options = g:replica_jupyter_console_options[&filetype]
  b:run_command = g:replica_run_commands[&filetype]

  if g:replica_enable_highlight
      augroup highlight_cells
          autocmd! * <buffer>
          autocmd BufEnter,BufWinEnter,WinEnter,WinLeave <buffer>
                      \ highlight.HighlightCell()
          autocmd CursorMoved,CursorMovedI <buffer>
                      \ highlight.HighlightCell(true)
      augroup END
  endif

  ftcommands_mappings.FtCommandsMappings()
enddef

augroup delete_tmp_file
    autocmd FileType * SetBufferVars()
augroup END

augroup delete_tmp_file
    autocmd VimLeave * delete(g:replica_tmp_filename)
augroup END
