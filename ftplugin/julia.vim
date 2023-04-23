vim9script

import autoload "../lib/replica.vim"

b:replica_kernel_name = g:replica_kernels[&filetype]
b:replica_name = g:replica_names[&filetype]
b:replica_cells_delimiter = g:replica_cells_delimiters[&filetype]
b:replica_run_command = g:replica_run_commands[&filetype]

augroup highlight_cells_julia
    autocmd!
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.jl replica.HighlightCell()
    autocmd CursorMoved,CursorMovedI *.jl replica.HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
augroup leave_replica_julia
    autocmd!
    autocmd BufWinLeave *.jl replica.ReplClose()
    autocmd BufWinEnter *.jl replica.ReplOpen() | replica.ReplClose('TERMINAL')
augroup END
