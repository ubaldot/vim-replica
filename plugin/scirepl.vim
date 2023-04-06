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


if !exists('g:sci_fast')
     g:sci_fast = false
endif

if !exists('g:sci_repl_direction')
     g:sci_repl_direction = "L"
endif

if !exists('g:sci_repl_size')
     g:sci_repl_size = 0
endif

# This leads the defaults
g:sci_kernel_default = 'terminal' # DONT CHANGE!

# Dicts. Keys must be Vim filetypes
var sci_kernels_default = {
            \ "python": "python3",
            \ "julia": "julia-1.8",
            \ "matlab": "jupyter_matlab_kernel",
            \ "terminal": "terminal"}

var sci_repl_names_default = {
            \ "python": "IPYTHON",
            \ "julia": "JULIA",
            \ "matlab": "MATLAB",
            \ "terminal": "TERMINAL"}

var sci_cells_delimiter_default = {
            \ "python": "# %%",
            \ "julia": "# %%",
            \ "matlab": "%%",
            \ "terminal": "#--"}

var sci_run_command_default = {
            \ "python": "run -i " .. g:sci_tmp_filename,
            \ "julia": 'include("' .. g:sci_tmp_filename .. '")',
            \ "matlab": 'run("' .. g:sci_tmp_filename .. '")',
            \ "terminal": "sh " .. g:sci_tmp_filename}

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


# Commands definition
command! SciReplToggle silent :call scirepl#ReplToggle(
            \ get(b:, 'sci_kernel_name', g:sci_kernels[g:sci_kernel_default]),
            \ get(b:, 'sci_repl_name', g:sci_repl_names[g:sci_kernel_default]),
            \ g:sci_repl_direction,
            \ g:sci_repl_size)

command! -range SciSendLines :call scirepl#SendLines(<line1>, <line2>,
            \ get(b:, 'sci_kernel_name', g:sci_kernels[g:sci_kernel_default] ),
            \ get(b:, 'sci_repl_name', g:sci_repl_names[g:sci_kernel_default]),
            \ g:sci_repl_direction,
            \ g:sci_repl_size)

command! SciSendCell silent :call scirepl#SendCell(
            \ get(b:, 'sci_kernel_name', g:sci_kernels[g:sci_kernel_default]),
            \ get(b:, 'sci_repl_name', g:sci_repl_names[g:sci_kernel_default]),
            \ get(b:, 'sci_cells_delimiter', g:sci_cells_delimiter[g:sci_kernel_default]),
            \ get(b:, 'sci_run_command', g:sci_run_commands[g:sci_kernel_default]),
            \ g:sci_tmp_filename,
            \ g:sci_repl_direction,
            \ g:sci_repl_size)

command! SciSendFile silent :call scirepl#SendFile(
            \ get(b:, 'sci_kernel_name', g:sci_kernels[g:sci_kernel_default]),
            \ get(b:, 'sci_repl_name', g:sci_repl_names[g:sci_kernel_default]),
            \ get(b:, 'sci_run_command', g:sci_run_commands[g:sci_kernel_default]),
            \ g:sci_tmp_filename,
            \ g:sci_repl_direction,
            \ g:sci_repl_size)

command! SciReplShutoff silent :call scirepl#ReplShutoff(get(b:, 'sci_repl_name', g:sci_repl_names[g:sci_kernel_default]))
command! SciRemoveCells silent :call scirepl#RemoveCells(get(b:, 'sci_cells_delimiter', g:sci_cells_delimiter[g:sci_kernel_default]))


# Default mappings
if !hasmapto('<Plug>SciSendLines')
    nnoremap <silent> <F9> <Cmd>SciSendLines<cr>
    xnoremap <silent> <F9> :SciSendLines<cr>
endif

if !hasmapto('<Plug>SciReplToggle')
    nnoremap <silent> <F2> <Cmd>SciReplToggle<cr>
    inoremap <silent> <F2> <Cmd>SciReplToggle<cr>
endif

if !hasmapto('<Plug>SciSendCell')
    nnoremap <silent> <c-enter> <Cmd>SciSendCell<cr>
endif
