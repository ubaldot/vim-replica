vim9script

b:repl_kernel_name = g:repl_kernels[&filetype]
b:repl_repl_name = g:repl_repl_names[&filetype]
b:repl_cells_delimiter = g:repl_cells_delimiters[&filetype]
b:repl_run_command = g:repl_run_commands[&filetype]

augroup highlight_cells_python
    autocmd!
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.py replica#HighlightCell()
    autocmd CursorMoved,CursorMovedI *.py replica#HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
augroup leave_repl_python
    autocmd!
    autocmd BufWinLeave *.py replica#ReplClose()
    autocmd BufWinEnter *.py replica#ReplOpen() | replica#ReplClose('TERMINAL')
augroup END
