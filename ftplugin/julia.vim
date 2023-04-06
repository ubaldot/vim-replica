vim9script

b:sci_kernel_name = g:sci_kernels[&filetype]
b:sci_repl_name = g:sci_repl_names[&filetype]
b:sci_cells_delimiter = g:sci_cells_delimiters[&filetype]
b:sci_run_command = g:sci_run_commands[&filetype]

augroup highlight_cells_julia
    autocmd!
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.jl scirepl#HighlightCell()
    autocmd CursorMoved,CursorMovedI *.jl scirepl#HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
augroup leave_repl_julia
    autocmd!
    autocmd BufWinLeave *.jl scirepl#ReplClose()
    autocmd BufWinEnter *.jl scirepl#ReplOpen() | scirepl#ReplClose('TERMINAL')
augroup END
