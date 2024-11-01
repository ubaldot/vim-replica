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

if exists('g:replica_loaded')
    finish
endif
g:replica_loaded = true

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

# -----------------------------
# Default mappings
# -----------------------------
#
import autoload "../lib/repl.vim"

# TODO: make imap and tmap to work.
noremap <unique> <script> <Plug>ReplicaConsoleToggle
            \ <ScriptCmd>repl.ConsoleToggle()<cr>
tnoremap <unique> <script> <Plug>ReplicaConsoleToggle
            \ <ScriptCmd>repl.ConsoleToggle()<cr>

noremap <unique> <script> <Plug>ReplicaSendLines
            \ <ScriptCmd>repl.SendLines(line('.'), line('.'))<cr>

noremap <unique> <script> <Plug>ReplicaSendFile
            \ <ScriptCmd>repl.SendFile()<cr>

noremap <unique> <script> <Plug>ReplicaSendCell
            \ <ScriptCmd>repl.SendCell()<cr>

if g:replica_use_default_mapping == true
    if !hasmapto('<Plug>ReplicaConsoleToggle') || empty(mapcheck("<F2>", "nt"))
        nnoremap <silent> <F2> <Plug>ReplicaConsoleToggle
        # imap <silent> <F2> <Plug>ReplicaConsoleToggle<cr>
        tnoremap <F2> <silent> <c-w><Plug>ReplicaConsoleToggle
    endif

    if !hasmapto('<Plug>ReplicaSendLines') || empty(mapcheck("<F9>", "nx"))
        nnoremap <silent> <unique> <F9> <Plug>ReplicaSendLines
        # imap <silent> <unique> <F9> <Plug>ReplicaSendLines<cr>
        xnoremap <silent> <unique> <F9> :ReplicaSendLines<cr>j
    endif

    if !hasmapto('<Plug>ReplicaSendFile') || empty(mapcheck("<F5>", "n"))
        nnoremap <silent> <F5> <Plug>ReplicaSendFile
        # imap <silent> <F5> <Plug>ReplicaSendFile<cr>
    endif

    if !hasmapto('<Plug>ReplicaSendCell') || empty(mapcheck("<c-enter>", "n"))
        nnoremap <silent> <c-enter> <Plug>ReplicaSendCell
        # imap <silent> <c-enter> <Plug>ReplicaSendCell<cr>j
    endif
endif


# -----------------------------
#  Commands
# -----------------------------
if !exists(":ReplicaConsoleToggle")
    command ReplicaConsoleToggle silent repl.ConsoleToggle()
endif

if !exists(":ReplicaConsoleRestart" )
    command ReplicaConsoleRestart silent repl.ConsoleShutoff() |
            \ repl.ConsoleToggle()
endif

if !exists(":ReplicaConsoleShutoff")
    command ReplicaConsoleShutoff repl.ConsoleShutoff()
endif

if !exists(":ReplicaSendLines")
    command -range ReplicaSendLines
            \ silent repl.SendLines(<line1>, <line2>)
endif

if !exists(":ReplicaSendCell")
    command ReplicaSendCell silent repl.SendCell()
endif

if !exists(":ReplicaSendFile")
    command -nargs=? -complete=file ReplicaSendFile
                \ silent repl.SendFile(<f-args>)
endif

if !exists(":ReplicaRemoveCells")
    command ReplicaRemoveCells repl.RemoveCells()
endif

augroup delete_tmp_file
    autocmd VimLeave * delete(g:replica_tmp_filename)
augroup END
