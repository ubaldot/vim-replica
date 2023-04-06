vim9script

b:sci_kernel_name = g:sci_kernels[&filetype]
b:sci_repl_name = g:sci_repl_names[&filetype]
b:sci_cells_delimiter = g:sci_cells_delimiters[&filetype]
b:sci_run_command = g:sci_run_commands[&filetype]

augroup highlight_cells_python
    autocmd!
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.py scirepl#HighlightCell()
    autocmd CursorMoved,CursorMovedI *.py scirepl#HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
augroup leave_repl_python
    autocmd!
    autocmd BufWinLeave *.py scirepl#ReplClose()
    autocmd BufWinEnter *.py scirepl#ReplOpen() | scirepl#ReplClose('TERMINAL')
augroup END
