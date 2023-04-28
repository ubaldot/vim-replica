vim9script

# Vim plugin to get an outline of your scripts.
# Maintainer:	Ubaldo Tiberi
# License: Vim license

if !has('vim9script') ||  v:version < 900
    # Needs Vim version 9.0 and above
    echo "You need at least Vim 9.0"
    finish
endif

if exists('g:replica_loaded')
    finish
endif
g:replica_loaded = true

# Temp file used for sending cells or files
g:replica_tmp_filename = tempname()

# if !exists('g:replica_console_autostart')
#     g:replica_console_autostart = true
# endif

if !exists('g:replica_alt_highlight')
    g:replica_alt_highlight = false
endif

if !exists('g:replica_console_position')
    g:replica_console_position = "L"
elseif index(["H", "J", "K", "L"], g:replica_console_position) == -1
    echoerr "g:replica_console_position must be one of HJKL"
endif


if !exists('g:replica_console_width')
    if index(["J", "K"], g:replica_console_position) >= 0
        g:replica_console_width = &columns
    else
        g:replica_console_width = floor(&columns / 2)
    endif
endif

if !exists('g:replica_console_height')
    if index(["H", "L"], g:replica_console_position) >= 0
        g:replica_console_height = &lines
    else
        g:replica_console_height = 10
    endif
endif

# Dicts. Keys must be Vim filetypes
var replica_kernels_default = {
            \ "python": "python3",
            \ "julia": "julia-1.8"}
            # \ "matlab": "jupyter_matlab_kernel",

var replica_console_names_default = {
            \ "python": "IPYTHON",
            \ "julia": "JULIA"}
            # \ "matlab": "MATLAB",

var replica_cells_delimiters_default = {
            \ "python": "# %%",
            \ "julia": "# %%"}
            # \ "matlab": "%%"

var replica_run_commands_default = {
            \ "python": "run -i " .. g:replica_tmp_filename,
            \ "julia": 'include("' .. g:replica_tmp_filename .. '")'}
            # \ "matlab": 'run("' .. g:replica_tmp_filename .. '")',


# User is allowed to change only replica_kernels and replica_cells_delimiters
if exists('g:replica_kernels')
    extend(replica_kernels_default, g:replica_kernels, "force")
endif

if exists('g:replica_cells_delimiters')
    extend(replica_delimiters_default, g:replica_cells_delimiters, "force")
endif

g:replica_kernels = replica_kernels_default
g:replica_cells_delimiters = replica_cells_delimiters_default
g:replica_console_names = replica_console_names_default
g:replica_run_commands = replica_run_commands_default

# -----------------------------
# Default mappings
# -----------------------------
#
import autoload "../lib/repl_funcs.vim"

noremap <unique> <script> <Plug>ReplicaConsoleToggle
            \ :call <SID>repl_funcs.ConsoleToggle()<cr>
if !hasmapto('<Plug>ReplicaConsoleToggle') || empty(mapcheck("<F2>", "nit"))
    nnoremap <silent> <F2> <Plug>ReplicaConsoleToggle<cr>
    inoremap <silent> <F2> <Plug>ReplicaConsoleToggle<cr>
    tnoremap <silent> <F2> <c-w><Plug>ReplicaConsoleToggle<cr>
endif

noremap <unique> <script> <Plug>ReplicaSendLines
            \ :call <SID>repl_funcs.SendLines(<line1>, <line2>)
if !hasmapto('<Plug>ReplicaSendLines') || empty(mapcheck("<F9>", "nix"))
    nnoremap <silent> <unique> <F9> <Plug>ReplicaSendLines
    inoremap <silent> <unique> <F9> <Plug>ReplicaSendLines
    xnoremap <silent> <unique> <F9> <Plug>ReplicaSendLines
endif

noremap <unique> <script> <Plug>ReplicaSendFile
            \ :call <SID>repl_funcs.SendFile(<f-args>)<cr>
if !hasmapto('<Plug>ReplicaSendFile') || empty(mapcheck("<F5>", "ni"))
    nnoremap <silent> <F5> <Plug>ReplicaSendFile<cr>
    inoremap <silent> <F5> <Plug>ReplicaSendFile<cr>
endif

noremap <unique> <script> <Plug>ReplicaSendCell
            \ :call <SID>repl_funcs.SendCell()<cr>
if !hasmapto('<Plug>ReplicaSendCell') || empty(mapcheck("<c-enter>", "ni"))
    nnoremap <silent> <c-enter> <Plug>ReplicaSendCell<cr>
    inoremap <silent> <c-enter> <Plug>ReplicaSendCell<cr>
endif


# -----------------------------
#  Commands
# -----------------------------
if !exists(":ReplicaConsoleToggle")
    command ReplicaConsoleToggle silent :call repl_funcs.ConsoleToggle()
endif

if !exists(":ReplicaConsoleRestart" )
    command ReplicaConsoleRestart silent :call repl_funcs.ConsoleShutoff() |
            \ repl_funcs.ConsoleToggle()
endif

if !exists(":ReplicaConsoleShutoff")
    command -nargs=? ReplicaConsoleShutoff
                \ :call repl_funcs.ConsoleShutoff(<f-args>)
endif

if !exists(":ReplicaSendLines")
    command -range ReplicaSendLines
            \ :call repl_funcs.SendLines(<line1>, <line2>)
endif

if !exists(":ReplicaSendCell")
    command ReplicaSendCell :call repl_funcs.SendCell()
endif

if !exists(":ReplicaSendFile")
    command -nargs=? -complete=file ReplicaSendFile
                \ :call repl_funcs.SendFile(<f-args>)
endif

if !exists(":ReplicaRemoveCells")
    command ReplicaRemoveCells :call repl_funcs.RemoveCells()
endif

augroup delete_tmp_file
    autocmd VimLeave * delete(g:replica_tmp_filename)
augroup END

def WipeoutConsoles()
    for buf_nr in term_list()
        # if index(values(g:replica_console_names), bufname(buf_nr))
            exe "bw! " .. buf_nr
        # endif
    endfor
enddef

augroup shoutoff_replica_consoles
    autocmd VimLeavePre * call WipeoutConsoles()
augroup END
