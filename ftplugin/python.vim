vim9script

# My python custom stuff
b:ugly_kernel_name = g:ugly_kernels[&filetype]
b:ugly_repl_name = 'IPYTHON'
b:ugly_cell_delimiter = g:ugly_delimiters[&filetype]
b:ugly_run_command = "run -i " .. g:ugly_tmp_filename

# Functions defined for debugging
def g:F(ugly_hlgrpID: number): number
    var ugly_hlgrpID_next = uglyrepl#HighlightCell(ugly_hlgrpID, b:ugly_cell_delimiter)
    # echo ugly_hlgrpID_next
    return ugly_hlgrpID_next
enddef

def g:G(): number
    echo "New match ID!"
    # echo ugly_hlgrpID_next
    return matchaddpos("CursorWord0", [1])
enddef

def g:H(ugly_hlgrpID: number)
    matchdelete(ugly_hlgrpID)
    echo "Deleted left match ID!"
enddef



augroup highlight_cell
    au!
    autocmd BufWinEnter  *.py w:ugly_hlgrpID = g:G()
    # autocmd CursorMoved,CursorMovedI *.py w:ugly_hlgrpID = uglyrepl#HighlightCell(w:ugly_hlgrpID, w:ugly_cell_delimiter)
    autocmd CursorMoved,CursorMovedI *.py w:ugly_hlgrpID = g:F(w:ugly_hlgrpID)
    autocmd BufWinLeave *.py g:H(w:ugly_hlgrpID)
augroup END

match Underlined  "# %%" # TODO
