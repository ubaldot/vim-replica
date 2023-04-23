vim9script

import autoload "../lib/replica.vim"

b:repl_kernel_name = g:repl_kernels[&filetype]
b:repl_name = g:repl_names[&filetype]
b:repl_cells_delimiter = g:repl_cells_delimiters[&filetype]
b:repl_run_command = g:repl_run_commands[&filetype]

augroup highlight_cells_julia
    autocmd!
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.jl replica.HighlightCell()
    autocmd CursorMoved,CursorMovedI *.jl replica.HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
augroup leave_repl_julia
    autocmd!
    autocmd BufWinLeave *.jl replica.ReplClose()
    autocmd BufWinEnter *.jl replica.ReplOpen() | replica.ReplClose('TERMINAL')
augroup END
