vim9script

import autoload "../lib/replica.vim"

# The following variable won't change during run-time
b:kernel_name = g:replica_kernels[&filetype]
b:console_name = g:replica_console_names[&filetype]
b:cells_delimiter = g:replica_cells_delimiters[&filetype]
b:run_command = g:replica_run_commands[&filetype]

augroup highlight_cells
    autocmd! * <buffer>
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave <buffer> replica.HighlightCell()
    autocmd CursorMoved,CursorMovedI <buffer> replica.HighlightCell(true)
augroup END
