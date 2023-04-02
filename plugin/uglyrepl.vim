if !has('vim9script') ||  v:version < 900
  " Needs Vim version 9.0 and above
  echo "You need at least Vim 9.0"
  finish
endif

vim9script

# scirepl.vim
# github.com/ubaldot/sci-repl


if exists('g:scivimrepl_loaded')
    finish
endif

g:scivimrepl_loaded = 1



# Defaults for the REPL
# To add another language define
#
# b:sci_kernel_name
# b:sci_repl_name
# b:sci_cell_delimiter
#
# in the ~/.vim/ftplugin folder by creating e.g. julia.vim file.
#
# To see all the kernel installed use jupyter kernelspec list

##

# Defaults
#
if has("gui_win32")
    g:sci_tmp_filename = $TMP .. "\\my_cell.tmp"
elseif has("mac")
    g:sci_tmp_filename = expand("~/my_cell.tmp")
endif


if !exists('g:sci_shell')
    if has("gui_win32")
        g:sci_shell = "powershell"
    elseif has("mac")
        g:sci_shell = "zsh"
    else
        echo "Try to set global variable g:shell"
endif

endif

if !exists('g:sci_kernel_name_default')
     g:sci_kernel_name_default = 'terminal'
endif

g:sci_delimiters = {"python": "# %%", "julia": "# %%"}
g:sci_kernels = {"python": "python3", "julia": "julia-1.8"}
g:sci_fast = false

g:sci_repl_name_default = "TERMINAL"
g:sci_cell_delimiter_default = "# %%"
# Perhaps we could define a default sci_run_command_default that align all the lines of
# TMP separated by &&, e.g. git add -u && git commit -m "foo" && ls ...
g:sci_run_command_default = "run -i" # TODO

# Commands definition
command! UglyReplOpen silent :call scirepl#Repl(get(b:, 'sci_kernel_name', g:sci_kernel_name_default), get(b:, 'sci_repl_name', g:sci_repl_name_default), g:sci_shell)
command! -range UglySendLines :call scirepl#SendLines(<line1>, <line2>, get(b:, 'sci_kernel_name', g:sci_kernel_name_default), get(b:, 'sci_repl_name', g:sci_repl_name_default), g:sci_shell)

command! UglySendCell silent :call scirepl#SendCell(get(b:, 'sci_kernel_name', g:sci_kernel_name_default), get(b:, 'sci_repl_name', g:sci_repl_name_default), get(b:, 'sci_cell_delimiter', g:sci_cell_delimiter_default), get(b:, 'sci_run_command', g:sci_run_command_default), g:sci_tmp_filename, g:sci_shell)

# Default mappings
if !hasmapto('<Plug>UglySendLines')
    nnoremap <silent> <F9> <Cmd>UglySendLines<cr>
    xnoremap <silent> <F9> :UglySendLines<cr>
endif


if !hasmapto('<Plug>UglySendCell')
    nnoremap <silent> <c-enter> <Cmd>UglySendCell<cr>
endif
