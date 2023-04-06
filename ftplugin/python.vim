vim9script

b:ubi_kernel_name = g:ubi_kernels[&filetype]
b:ubi_repl_name = g:ubi_repl_names[&filetype]
b:ubi_cells_delimiter = g:ubi_cells_delimiters[&filetype]
b:ubi_run_command = g:ubi_run_commands[&filetype]

augroup highlight_cells_python
    autocmd!
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.py ubiquiotous#HighlightCell()
    autocmd CursorMoved,CursorMovedI *.py ubiquiotous#HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
augroup leave_repl_python
    autocmd!
    autocmd BufWinLeave *.py ubiquiotous#ReplClose()
    autocmd BufWinEnter *.py ubiquiotous#ReplOpen() | ubiquiotous#ReplClose('TERMINAL')
augroup END
