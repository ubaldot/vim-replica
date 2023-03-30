if !has('vim9script') ||  v:version < 900
  " Needs Vim version 9.0 and above
  echo "You need at least Vim 9.0"
  finish
endif

vim9script

# scirepl.vim
# github.com/ubaldot/sci-repl


if exists('g:plugin_uglyrepl')
    finish
endif

g:plugin_uglyrepl = 1


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

g:ugly_repl_name_default = "TERMINAL"
g:ugly_cell_delimiter_default = "# %%"
# Perhaps we could define a default ugly_run_command_default that align all the lines of
# TMP separated by &&, e.g. git add -u && git commit -m "foo" && ls ...
g:ugly_run_command_default = "run -i" # TODO

command! UglyReplOpen silent :call uglyrepl#Repl(get(b:, 'ugly_kernel_name', g:ugly_kernel_name_default), get(b:, 'ugly_repl_name', g:ugly_repl_name_default), g:ugly_shell)
command! -range UglySendLines :call uglyrepl#SendLines(<line1>, <line2>, get(b:, 'ugly_kernel_name', g:ugly_kernel_name_default), get(b:, 'ugly_repl_name', g:ugly_repl_name_default), g:ugly_shell)

nnoremap <silent> <F9> <Cmd>UglySendLines<cr>
xnoremap <silent> <F9> :UglySendLines<cr>


# command! UglySendCell silent :call uglyrepl#SendCell(
#     get(b:, 'ugly_kernel_name', g:ugly_kernel_name_default),
#     get(b:, 'ugly_repl_name', g:ugly_repl_name_default),
#     get(b:, 'ugly_cell_delimiter', g:ugly_cell_delimiter_default),
#     get(b:, 'ugly_run_command', g:ugly_run_command_default), g:ugly_tmp_filename,
#     g:ugly_shell)<cr><cr>



# Some key-bindings for the REPL
# nnoremap <silent> <F9> yy \| :call term_sendkeys(get(b:, 'ugly_repl_name', ugly_repl_name_default),@")<cr>j0
# xnoremap <silent> <F9> y \| :<c-u>call term_sendkeys(get(b:, 'ugly_repl_name', ugly_repl_name_default),@")<cr>j0
# nnoremap <silent> <c-enter> \| :call g:SendCell(get(b:, 'ugly_kernel_name', g:ugly_kernel_name_default), get(b:, 'ugly_repl_name', ugly_repl_name_default), get(b:, 'ugly_cell_delimiter', ugly_cell_delimiter_default), get(b:, 'ugly_run_command', ugly_run_command_default))<cr><cr>
# Clear REPL
# nnoremap <c-c> :call term_sendkeys(get(b:, 'ugly_repl_name', ugly_repl_name_default),"\<c-l>")<cr>
