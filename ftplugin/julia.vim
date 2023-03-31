vim9script

b:ugly_kernel_name = "julia-1.8"
b:ugly_repl_name = 'JULIA'
b:ugly_cell_delimiter = g:ugly_delimiters[&filetype]
b:ugly_run_command = 'include("' .. g:ugly_tmp_filename .. '")'

# b:hlgrpID = matchaddpos("CursorWord0", [1])
# augroup highlight_cell
#     au!
#     autocmd BufEnter,CursorMoved,CursorMovedI global b:hlgrpID = uglyrepl#HighlightCell(b:hlgrpID)
# augroup END

# match Underlined  "# %%"
