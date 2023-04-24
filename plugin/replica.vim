vim9script

# Vim plugin to get an outline for your scripts.
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

# Used for sending cells or files
g:replica_tmp_filename = tempname()

# if !exists('g:replica_is_open')
#      g:replica_is_open = false
# endif

if !exists('g:replica_console_autostart')
    g:replica_console_autostart = true
endif

if !exists('g:replica_alt_highlight')
    g:replica_alt_highlight = false
endif

if !exists('g:replica_console_direction')
    g:replica_console_direction = "L"
endif

if !exists('g:replica_console_size')
    g:replica_console_size = 0 # Use 0 to take the half of the whole space
endif


# Dicts. Keys must be Vim filetypes
var replica_kernels_default = {
            \ "python": "python3",
            \ "julia": "julia-1.8",
            \ "matlab": "jupyter_matlab_kernel",
            \ "default": "terminal"}

var replica_console_names_default = {
            \ "python": "IPYTHON",
            \ "julia": "JULIA",
            \ "matlab": "MATLAB",
            \ "default": "TERMINAL"}

var replica_cells_delimiters_default = {
            \ "python": "# %%",
            \ "julia": "# %%",
            \ "matlab": "%%",
            \ "default": "#--"}

var replica_run_commands_default = {
            \ "python": "run -i " .. g:replica_tmp_filename,
            \ "julia": 'include("' .. g:replica_tmp_filename .. '")',
            \ "matlab": 'run("' .. g:replica_tmp_filename .. '")',
            \ "default": "sh " .. g:replica_tmp_filename}


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

g:replica_open_buffers = {
            \ "python": [],
            \ "julia": [],
            \ "matlab": [],
            \ "default": []}


# -----------------------------
# Default mappings
# -----------------------------
#
import autoload "../lib/replica.vim"

noremap <unique> <script> <Plug>ReplicaConsoleToggle
            \ :call <SID>replica.ConsoleToggle()<cr>
if !hasmapto('<Plug>ReplicaConsoleToggle') || empty(mapcheck("<F2>", "nit"))
    nnoremap <silent> <F2> <Plug>ReplicaConsoleToggle<cr>
    inoremap <silent> <F2> <Plug>ReplicaConsoleToggle<cr>
    tnoremap <silent> <F2> <Plug>ReplicaConsoleToggle<cr>
endif

noremap <unique> <script> <Plug>ReplicaSendLines
            \ :call <SID>replica.SendLines(<line1>, <line2>)<cr>
if !hasmapto('<Plug>ReplicaSendLines') || empty(mapcheck("<F9>", "nix"))
    nnoremap <silent> <unique> <F9> <Plug>ReplicaSendLines
    inoremap <silent> <unique> <F9> <Plug>ReplicaSendLines
    xnoremap <silent> <unique> <F9> <Plug>ReplicaSendLines
endif

noremap <unique> <script> <Plug>ReplicaSendFile
            \ :call <SID>replica.SendFile(<f-args>)<cr>
if !hasmapto('<Plug>ReplicaSendFile') || empty(mapcheck("<F5>", "ni"))
    nnoremap <silent> <F5> <Plug>ReplicaSendFile<cr>
    inoremap <silent> <F5> <Plug>ReplicaSendFile<cr>
endif

noremap <unique> <script> <Plug>ReplicaSendCell
            \ :call <SID>replica.SendCell()<cr>
if !hasmapto('<Plug>ReplicaSendCell') || empty(mapcheck("<c-enter>", "ni"))
    nnoremap <silent> <c-enter> <Plug>ReplicaSendCell<cr>
    inoremap <silent> <c-enter> <Plug>ReplicaSendCell<cr>
endif


# -----------------------------
#  Commands
# -----------------------------
if !exists(":ReplicaConsoleOpen")
    command ReplicaConsoleOpen silent call replica.ConsoleOpen()
endif

if !exists(":ReplicaConsoleClose")
    command -nargs=? ReplicaConsoleClose
                \ silent :call replica.ConsoleClose(<f-args>)
endif

if !exists(":ReplicaConsoleToggle")
    command ReplicaConsoleToggle silent :call replica.ConsoleToggle()
endif

if !exists(":ReplicaConsoleRestart" )
    command ReplicaConsoleRestart silent :call replica.ConsoleShutoff() |
            \ replica.ConsoleOpen()
endif

if !exists(":ReplicaConsoleShutoff")
    command -nargs=? ReplicaConsoleShutoff
                \ silent :call replica.ConsoleShutoff(<f-args>)
endif

if !exists(":ReplicaSendLines")
    command -range ReplicaSendLines
            \ silent :call replica.SendLines(<line1>, <line2>)
endif

if !exists(":ReplicaSendCell")
    command ReplicaSendCell silent :call replica.SendCell()
endif

if !exists(":ReplicaSendFile")
    command -nargs=? -complete=file ReplicaSendFile
                \ silent :call replica.SendFile(<f-args>)
endif

if !exists(":ReplicaRemoveCells")
    command ReplicaRemoveCells silent :call replica.RemoveCells()
endif
