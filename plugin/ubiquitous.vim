if !has('vim9script') ||  v:version < 900
  " Needs Vim version 9.0 and above
  echo "You need at least Vim 9.0"
  finish
endif

vim9script

# ubiquitous.vim
# github.com/ubaldot/sci-vim-repl

if exists('g:scivimrepl_loaded')
    finish
endif

g:scivimrepl_loaded = 1

# Used for sending cells or files
g:ubi_tmp_filename = tempname()

if !exists('g:alt_highlight')
     g:alt_highlight = false
endif

if !exists('g:ubi_repl_direction')
     g:ubi_repl_direction = "L"
endif

if !exists('g:ubi_repl_size')
     g:ubi_repl_size = 0 # Use 0 to take the half of the whole space
endif


# Dicts. Keys must be Vim filetypes
var ubi_kernels_default = {
            \ "python": "python3",
            \ "julia": "julia-1.8",
            \ "matlab": "jupyter_matlab_kernel",
            \ "default": "terminal"}

var ubi_repl_names_default = {
            \ "python": "IPYTHON",
            \ "julia": "JULIA",
            \ "matlab": "MATLAB",
            \ "default": "TERMINAL"}

var ubi_cells_delimiters_default = {
            \ "python": "# %%",
            \ "julia": "# %%",
            \ "matlab": "%%",
            \ "default": "#--"}

var ubi_run_commands_default = {
            \ "python": "run -i " .. g:ubi_tmp_filename,
            \ "julia": 'include("' .. g:ubi_tmp_filename .. '")',
            \ "matlab": 'run("' .. g:ubi_tmp_filename .. '")',
            \ "default": "sh " .. g:ubi_tmp_filename}



# User is allowed to change only ubi_kernels and ubi_cells_delimiters
if exists('g:ubi_kernels')
    extend(ubi_kernels_default, g:ubi_kernels, "force")
endif

if exists('g:ubi_cells_delimiters')
    extend(ubi_delimiters_default, g:ubi_cells_delimiters, "force")
endif

g:ubi_kernels = ubi_kernels_default
g:ubi_cells_delimiters = ubi_cells_delimiters_default
g:ubi_repl_names = ubi_repl_names_default
g:ubi_run_commands = ubi_run_commands_default


# Commands definition: if a key (&filetype) don't exist in the defined dicts, use a default (= "default").
command! UbiReplOpen silent :call ubiquitous#ReplOpen()
command! -nargs=? UbiReplClose silent :call ubiquitous#ReplClose(<f-args>)
command! UbiReplToggle silent :call ubiquitous#ReplToggle()
command! UbiReplRestart silent :call ubiquitous#ReplShutoff() | ubiquitous#ReplOpen()
command! -nargs=? UbiReplShutoff silent :call ubiquitous#ReplShutoff(<f-args>)

command! -range UbiSendLines silent :call ubiquitous#SendLines(<line1>, <line2>)
command! UbiSendCell silent :call ubiquitous#SendCell()
command! -nargs=? -complete=file UbiSendFile silent :call ubiquitous#SendFile(<f-args>)

command! UbiRemoveCells silent :call ubiquitous#RemoveCells()


# Default mappings
if !hasmapto('<Plug>UbiSendLines') || empty(mapcheck("<F9>", "nix"))
    nnoremap <silent> <F9> <Cmd>UbiSendLines<cr>
    inoremap <silent> <F9> <Cmd>UbiSendLines<cr>
    xnoremap <silent> <F9> :UbiSendLines<cr>
endif

if !hasmapto('<Plug>UbiSendFile') || empty(mapcheck("<F5>", "ni"))
    nnoremap <silent> <F5> <Cmd>UbiSendFile<cr>
    inoremap <silent> <F5> <Cmd>UbiSendFile<cr>
endif

if !hasmapto('<Plug>UbiReplToggle') || empty(mapcheck("<F2>", "nit"))
    nnoremap <silent> <F2> <Cmd>UbiReplToggle<cr>
    inoremap <silent> <F2> <Cmd>UbiReplToggle<cr>
    tnoremap <silent> <F2> <Cmd>UbiReplToggle<cr>
endif

if !hasmapto('<Plug>UbiSendCell') || empty(mapcheck("<c-enter>", "ni"))
    nnoremap <silent> <c-enter> <Cmd>UbiSendCell<cr>
    inoremap <silent> <c-enter> <Cmd>UbiSendCell<cr>
endif
