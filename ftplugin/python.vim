vim9script

# My python custom stuff
b:sci_kernel_name = g:sci_kernels[&filetype]
b:sci_repl_name = 'IPYTHON'
b:sci_cell_delimiter = g:sci_delimiters[&filetype]
b:sci_run_command = "run -i " .. g:sci_tmp_filename

augroup highlight_cells
    autocmd CursorMoved,CursorMovedI,BufEnter *.py uglyrepl#HighlightCell(b:sci_cell_delimiter, g:sci_fast)
augroup END
