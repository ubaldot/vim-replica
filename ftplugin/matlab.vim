vim9script

import autoload "../lib/replica.vim"

b:repl_kernel_name = g:repl_kernels[&filetype]
b:repl_name = g:repl_names[&filetype]
b:repl_cells_delimiter = g:repl_cells_delimiters[&filetype]
b:repl_run_command = g:repl_run_commands[&filetype]

augroup highlight_cells_matlab
    autocmd!
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.m replica.HighlightCell()
    autocmd CursorMoved,CursorMovedI *.m replica.HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
augroup leave_repl_matlab
    autocmd!
    autocmd BufWinLeave *.m replica.ReplClose()
    autocmd BufWinEnter *.m replica.ReplOpen() | replica.ReplClose('TERMINAL')
augroup END
