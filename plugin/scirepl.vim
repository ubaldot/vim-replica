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

# Used for sending cells or files
g:sci_tmp_filename = tempname()

if !exists('g:alt_highlight')
     g:alt_highlight = false
endif

if !exists('g:sci_repl_direction')
     g:sci_repl_direction = "L"
endif

if !exists('g:sci_repl_size')
     g:sci_repl_size = 0 # Use 0 to take the half of the whole space
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
command! SciReplOpen silent :call scirepl#ReplOpen()
command! -nargs=? SciReplClose silent :call scirepl#ReplClose(<f-args>)
command! SciReplToggle silent :call scirepl#ReplToggle()
command! SciReplRestart silent :call scirepl#ReplShutoff() | scirepl#ReplOpen()
command! -nargs=? SciReplShutoff silent :call scirepl#ReplShutoff(<f-args>)

command! -range SciSendLines silent :call scirepl#SendLines(<line1>, <line2>)
command! SciSendCell silent :call scirepl#SendCell()
command! -nargs=? -complete=file SciSendFile silent :call scirepl#SendFile(<f-args>)

command! SciRemoveCells silent :call scirepl#RemoveCells()


# Default mappings
if !hasmapto('<Plug>SciSendLines') || empty(mapcheck("<F9>", "nix"))
    nnoremap <silent> <F9> <Cmd>SciSendLines<cr>
    inoremap <silent> <F9> <Cmd>SciSendLines<cr>
    xnoremap <silent> <F9> :SciSendLines<cr>
endif

if !hasmapto('<Plug>SciSendFile') || empty(mapcheck("<F5>", "ni"))
    nnoremap <silent> <F5> <Cmd>SciSendFile<cr>
    inoremap <silent> <F5> <Cmd>SciSendFile<cr>
endif

if !hasmapto('<Plug>SciReplToggle') || empty(mapcheck("<F2>", "nit"))
    nnoremap <silent> <F2> <Cmd>SciReplToggle<cr>
    inoremap <silent> <F2> <Cmd>SciReplToggle<cr>
    tnoremap <silent> <F2> <Cmd>SciReplToggle<cr>
endif

if !hasmapto('<Plug>SciSendCell') || empty(mapcheck("<c-enter>", "ni"))
    nnoremap <silent> <c-enter> <Cmd>SciSendCell<cr>
    inoremap <silent> <c-enter> <Cmd>SciSendCell<cr>
endif
