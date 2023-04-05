if !has('vim9script') ||  v:version < 900
  " Needs Vim version 9.0 and above
  echo "You need at least Vim 9.0"
  finish
endif

vim9script

# scirepl.vim
# github.com/ubaldot/sci-vim-repl

if exists('g:scivimrepl_loaded')
    finish
endif

g:scivimrepl_loaded = 1

if has("gui_win32")
    g:sci_tmp_filename = $TMP .. "\\my_cell.tmp"
elseif has("mac")
    g:sci_tmp_filename = expand($TMPDIR .. "/my_cell.tmp")
endif

if !exists('g:sci_shell')
    if has("gui_win32")
        g:sci_shell = "powershell"
    elseif has("mac")
        g:sci_shell = "zsh"
    else
        echo "Try to set global variable g:shell"
    endif
endif

if !exists('g:sci_fast')
     g:sci_fast = false
endif


# This leads the defaults
if !exists('g:sci_kernel_default')
     g:sci_kernel_default = 'terminal' # Must be a vim filetype
endif

var sci_kernels_default = {"python": "python3", "julia": "julia-1.8", "matlab": "matlab", "terminal": "terminal"}
var sci_repl_names_default = {"python": "IPYTHON", "julia": "JULIA", "matlab": "MATLAB", "terminal": "TERMINAL"}
var sci_cells_delimiter_default = {"python": "# %%", "julia": "# %%", "matlab": "%%", "terminal": ""}
var sci_run_command_default = {
            \ "python": "run -i " .. g:sci_tmp_filename,
            \ "julia": 'include("' .. g:sci_tmp_filename .. '")',
            \ "matlab": 'run("' .. g:sci_tmp_filename .. '")'
            \ "terminal": ""}

# User is allowed to change only sci_kernels and sci_cells_delimiters
if exists('g:sci_kernels')
    extend(sci_kernels_default, g:sci_kernels, "force")
endif

if exists('g:sci_cells_delimiter')
    extend(sci_delimiters_default, g:sci_cells_delimiter, "force")
endif

g:sci_kernels = sci_kernels_default
g:sci_cells_delimiter = sci_cells_delimiter_default
g:sci_repl_names = sci_repl_names_default
g:sci_run_commands = sci_run_command_default

# These cannot be changed
# Perhaps we could define a default sci_run_command_default that align all the lines of
# TMP separated by &&, e.g. git add -u && git commit -m "foo" && ls ...

# Commands definition
command! SciReplOpen silent :call scirepl#Repl(
            \ get(b:, 'sci_kernel_name', g:sci_kernels[g:sci_kernel_default]),
            \ get(b:, 'sci_repl_name', g:sci_repl_names[g:sci_kernel_default]),
            \ g:sci_shell)

command! -range SciSendLines :call scirepl#SendLines(<line1>, <line2>,
            \ get(b:, 'sci_kernel_name',g:sci_kernels[g:sci_kernel_default] ),
            \ get(b:, 'sci_repl_name', g:sci_repl_names[g:sci_kernel_default]),
            \ g:sci_shell)

command! SciSendCell silent :call scirepl#SendCell(
            \ get(b:, 'sci_kernel_name', g:sci_kernels[g:sci_kernel_default]),
            \ get(b:, 'sci_repl_name', g:sci_repl_names[g:sci_kernel_default]),
            \ get(b:, 'sci_cell_delimiter', g:sci_cells_delimiter[g:sci_kernel_default]),
            \ get(b:, 'sci_run_command', g:sci_run_commands[g:sci_kernel_default]),
            \ g:sci_tmp_filename,
            \ g:sci_shell)

# Default mappings
if !hasmapto('<Plug>SciSendLines')
    nnoremap <silent> <F9> <Cmd>SciSendLines<cr>
    xnoremap <silent> <F9> :SciSendLines<cr>
endif


if !hasmapto('<Plug>SciSendCell')
    nnoremap <silent> <c-enter> <Cmd>SciSendCell<cr>
endif
