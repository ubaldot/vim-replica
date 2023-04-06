vim9script

b:sci_kernel_name = g:sci_kernels[&filetype]
b:sci_repl_name = g:sci_repl_names[&filetype]
b:sci_cells_delimiter = g:sci_cells_delimiters[&filetype]
b:sci_run_command = g:sci_run_commands[&filetype]


augroup highlight_cells
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.jl scirepl#HighlightCell(b:sci_cells_delimiter, g:sci_fast)
    autocmd CursorMoved,CursorMovedI *.jl scirepl#HighlightCell(b:sci_cells_delimiter, g:sci_fast, true)
augroup END
