vim9script

b:ubi_kernel_name = g:ubi_kernels[&filetype]
b:ubi_repl_name = g:ubi_repl_names[&filetype]
b:ubi_cells_delimiter = g:ubi_cells_delimiters[&filetype]
b:ubi_run_command = g:ubi_run_commands[&filetype]

augroup highlight_cells_matlab
    autocmd!
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.m ubiquiotous#HighlightCell()
    autocmd CursorMoved,CursorMovedI *.m ubiquiotous#HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
augroup leave_repl_matlab
    autocmd!
    autocmd BufWinLeave *.m ubiquiotous#ReplClose()
    autocmd BufWinEnter *.m ubiquiotous#ReplOpen() | ubiquiotous#ReplClose('TERMINAL')
augroup END
