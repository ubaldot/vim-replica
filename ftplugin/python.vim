vim9script

# My python custom stuff
b:ugly_kernel_name = g:ugly_kernels[&filetype]
b:ugly_repl_name = 'IPYTHON'
b:ugly_cell_delimiter = g:ugly_delimiters[&filetype]
b:ugly_run_command = "run -i " .. g:ugly_tmp_filename

augroup highlight_cells
    autocmd CursorMoved,CursorMovedI,BufEnter *.py uglyrepl#HighlightCell(b:ugly_cell_delimiter, g:ugly_fast)
augroup END
