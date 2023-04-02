vim9script

b:sci_kernel_name = "julia-1.8"
b:sci_repl_name = 'JULIA'
b:sci_cell_delimiter = g:sci_delimiters[&filetype]
b:sci_run_command = 'include("' .. g:sci_tmp_filename .. '")'

augroup highlight_cells
    autocmd CursorMoved,CursorMovedI,BufEnter *.jl uglyrepl#HighlightCell(b:sci_cell_delimiter, g:sci_fast)
augroup END
