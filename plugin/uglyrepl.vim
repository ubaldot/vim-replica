if !has('vim9script') ||  v:version < 900
  " Needs Vim version 9.0 and above
  echo "You need at least Vim 9.0"
  finish
endif

vim9script

# scirepl.vim
# github.com/ubaldot/sci-repl


if exists('g:uglyvimrepl_loaded')
    finish
endif

g:uglyvimrepl_loaded = 1



# Defaults for the REPL
# To add another language define
#
# b:ugly_kernel_name
# b:ugly_repl_name
# b:ugly_cell_delimiter
#
# in the ~/.vim/ftplugin folder by creating e.g. julia.vim file.
#
# To see all the kernel installed use jupyter kernelspec list

##

# Defaults
#
if has("gui_win32")
    g:ugly_tmp_filename = $TMP .. "\\my_cell.tmp"
elseif has("mac")
    g:ugly_tmp_filename = expand("~/my_cell.tmp")
endif


if !exists('g:ugly_shell')
    if has("gui_win32")
        g:ugly_shell = "powershell"
    elseif has("mac")
        g:ugly_shell = "zsh"
    else
        echo "Try to set global variable g:shell"
endif

endif

if !exists('g:ugly_kernel_name_default')
     g:ugly_kernel_name_default = 'terminal'
endif

g:ugly_delimiters = {"python": "# %%", "julia": "# %%"}
g:ugly_kernels = {"python": "python3", "julia": "julia-1.8"}
g:ugly_fast = false

g:ugly_repl_name_default = "TERMINAL"
g:ugly_cell_delimiter_default = "# %%"
# Perhaps we could define a default ugly_run_command_default that align all the lines of
# TMP separated by &&, e.g. git add -u && git commit -m "foo" && ls ...
g:ugly_run_command_default = "run -i" # TODO

# Commands definition
command! UglyReplOpen silent :call uglyrepl#Repl(get(b:, 'ugly_kernel_name', g:ugly_kernel_name_default), get(b:, 'ugly_repl_name', g:ugly_repl_name_default), g:ugly_shell)
command! -range UglySendLines :call uglyrepl#SendLines(<line1>, <line2>, get(b:, 'ugly_kernel_name', g:ugly_kernel_name_default), get(b:, 'ugly_repl_name', g:ugly_repl_name_default), g:ugly_shell)

command! UglySendCell silent :call uglyrepl#SendCell(get(b:, 'ugly_kernel_name', g:ugly_kernel_name_default), get(b:, 'ugly_repl_name', g:ugly_repl_name_default), get(b:, 'ugly_cell_delimiter', g:ugly_cell_delimiter_default), get(b:, 'ugly_run_command', g:ugly_run_command_default), g:ugly_tmp_filename, g:ugly_shell)

# Default mappings
if !hasmapto('<Plug>UglySendLines')
    nnoremap <silent> <F9> <Cmd>UglySendLines<cr>
    xnoremap <silent> <F9> :UglySendLines<cr>
endif


if !hasmapto('<Plug>UglySendCell')
    nnoremap <silent> <c-enter> <Cmd>UglySendCell<cr>
endif
