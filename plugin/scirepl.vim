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


g:sci_tmp_filename = tempname()
# if has("gui_win32")
#     g:sci_tmp_filename = $TMP .. "\\my_cell.tmp"
# else
#     g:sci_tmp_filename = expand($TMPDIR .. "/my_cell.tmp")
# endif


if !exists('g:sci_fast')
     g:sci_fast = false
endif

if !exists('g:sci_repl_direction')
     g:sci_repl_direction = "L"
endif

if !exists('g:sci_repl_size')
     g:sci_repl_size = 0
endif


# Dicts. Keys must be Vim filetypes
var sci_kernels_default = {
            \ "python": "python3",
            \ "julia": "julia-1.8",
            \ "matlab": "jupyter_matlab_kernel",
            \ "default": "terminal"}

var sci_repl_names_default = {
            \ "python": "IPYTHON",
            \ "julia": "JULIA",
            \ "matlab": "MATLAB",
            \ "default": "TERMINAL"}

var sci_cells_delimiters_default = {
            \ "python": "# %%",
            \ "julia": "# %%",
            \ "matlab": "%%",
            \ "default": "#--"}

var sci_run_commands_default = {
            \ "python": "run -i " .. g:sci_tmp_filename,
            \ "julia": 'include("' .. g:sci_tmp_filename .. '")',
            \ "matlab": 'run("' .. g:sci_tmp_filename .. '")',
            \ "default": "sh " .. g:sci_tmp_filename}



# User is allowed to change only sci_kernels and sci_cells_delimiters
if exists('g:sci_kernels')
    extend(sci_kernels_default, g:sci_kernels, "force")
endif

if exists('g:sci_cells_delimiters')
    extend(sci_delimiters_default, g:sci_cells_delimiters, "force")
endif

g:sci_kernels = sci_kernels_default
g:sci_cells_delimiters = sci_cells_delimiters_default
g:sci_repl_names = sci_repl_names_default
g:sci_run_commands = sci_run_commands_default


# Commands definition: if a key (&filetype) don't exist in the defined dicts, use a default (= "default").
command! SciReplToggle silent :call scirepl#ReplToggle()
command! -range SciSendLines silent :call scirepl#SendLines(<line1>, <line2>)
command! SciSendCell silent :call scirepl#SendCell()
command! -nargs=? -complete=file SciSendFile silent :call scirepl#SendFile(<f-args>)
command! -nargs=? -complete=buffer SciReplShutoff silent :call scirepl#ReplShutoff(<f-args>)
command! SciRemoveCells silent :call scirepl#RemoveCells()
command! SciReplRestart silent :call scirepl#ReplShutoff() | scirepl#ReplOpen()


# Default mappings
if !hasmapto('<Plug>SciSendLines')
    nnoremap <silent> <F9> <Cmd>SciSendLines<cr>
    xnoremap <silent> <F9> :SciSendLines<cr>
endif

if !hasmapto('<Plug>SciReplToggle')
    nnoremap <silent> <F2> <Cmd>SciReplToggle<cr>
    inoremap <silent> <F2> <Cmd>SciReplToggle<cr>
    tnoremap <silent> <F2> <Cmd>SciReplToggle<cr>
endif

if !hasmapto('<Plug>SciSendCell')
    nnoremap <silent> <c-enter> <Cmd>SciSendCell<cr>
endif
