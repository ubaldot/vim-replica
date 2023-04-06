vim9script

b:ubi_kernel_name = g:ubi_kernels[&filetype]
b:ubi_repl_name = g:ubi_repl_names[&filetype]
b:ubi_cells_delimiter = g:ubi_cells_delimiters[&filetype]
b:ubi_run_command = g:ubi_run_commands[&filetype]

augroup highlight_cells_julia
    autocmd!
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.jl ubiquiotous#HighlightCell()
    autocmd CursorMoved,CursorMovedI *.jl ubiquiotous#HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
augroup leave_repl_julia
    autocmd!
    autocmd BufWinLeave *.jl ubiquiotous#ReplClose()
    autocmd BufWinEnter *.jl ubiquiotous#ReplOpen() | ubiquiotous#ReplClose('TERMINAL')
augroup END
