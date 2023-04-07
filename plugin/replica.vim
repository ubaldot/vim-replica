if !has('vim9script') ||  v:version < 900
  " Needs Vim version 9.0 and above
  echo "You need at least Vim 9.0"
  finish
endif

vim9script

# replica.vim
# github.com/ubaldot/vim-replica

if exists('g:scivimrepl_loaded')
    finish
endif

g:scivimrepl_loaded = 1


# Used for sending cells or files
g:repl_tmp_filename = tempname()

if !exists('g:repl_alt_highlight')
     g:repl_alt_highlight = false
endif

if !exists('g:repl_direction')
     g:repl_direction = "L"
endif

if !exists('g:repl_size')
     g:repl_size = 0 # Use 0 to take the half of the whole space
endif


# Dicts. Keys must be Vim filetypes
var repl_kernels_default = {
            \ "python": "python3",
            \ "julia": "julia-1.8",
            \ "matlab": "jupyter_matlab_kernel",
            \ "default": "terminal"}

var repl_names_default = {
            \ "python": "IPYTHON",
            \ "julia": "JULIA",
            \ "matlab": "MATLAB",
            \ "default": "TERMINAL"}

var repl_cells_delimiters_default = {
            \ "python": "# %%",
            \ "julia": "# %%",
            \ "matlab": "%%",
            \ "default": "#--"}

var repl_run_commands_default = {
            \ "python": "run -i " .. g:repl_tmp_filename,
            \ "julia": 'include("' .. g:repl_tmp_filename .. '")',
            \ "matlab": 'run("' .. g:repl_tmp_filename .. '")',
            \ "default": "sh " .. g:repl_tmp_filename}



# User is allowed to change only repl_kernels and repl_cells_delimiters
if exists('g:repl_kernels')
    extend(repl_kernels_default, g:repl_kernels, "force")
endif

if exists('g:repl_cells_delimiters')
    extend(repl_delimiters_default, g:repl_cells_delimiters, "force")
endif

g:repl_kernels = repl_kernels_default
g:repl_cells_delimiters = repl_cells_delimiters_default
g:repl_names = repl_names_default
g:repl_run_commands = repl_run_commands_default


# Commands definition: if a key (&filetype) don't exist in the defined dicts, use a default (= "default").
command! ReplOpen silent :call replica#ReplOpen()
command! -nargs=? ReplClose silent :call replica#ReplClose(<f-args>)
command! ReplToggle silent :call replica#ReplToggle()
command! ReplRestart silent :call replica#ReplShutoff() | replica#ReplOpen()
command! -nargs=? ReplShutoff silent :call replica#ReplShutoff(<f-args>)

command! -range ReplSendLines silent :call replica#SendLines(<line1>, <line2>)
command! ReplSendCell silent :call replica#SendCell()
command! -nargs=? -complete=file ReplSendFile silent :call replica#SendFile(<f-args>)

command! ReplRemoveCells silent :call replica#RemoveCells()


# Default mappings
if !hasmapto('<Plug>ReplSendLines') || empty(mapcheck("<F9>", "nix"))
    nnoremap <silent> <F9> <Cmd>ReplSendLines<cr>
    inoremap <silent> <F9> <Cmd>ReplSendLines<cr>
    xnoremap <silent> <F9> :ReplSendLines<cr>
endif

if !hasmapto('<Plug>ReplSendFile') || empty(mapcheck("<F5>", "ni"))
    nnoremap <silent> <F5> <Cmd>ReplSendFile<cr>
    inoremap <silent> <F5> <Cmd>ReplSendFile<cr>
endif

if !hasmapto('<Plug>ReplToggle') || empty(mapcheck("<F2>", "nit"))
    nnoremap <silent> <F2> <Cmd>ReplToggle<cr>
    inoremap <silent> <F2> <Cmd>ReplToggle<cr>
    tnoremap <silent> <F2> <Cmd>ReplToggle<cr>
endif

if !hasmapto('<Plug>ReplSendCell') || empty(mapcheck("<c-enter>", "ni"))
    nnoremap <silent> <c-enter> <Cmd>ReplSendCell<cr>
    inoremap <silent> <c-enter> <Cmd>ReplSendCell<cr>
endif
