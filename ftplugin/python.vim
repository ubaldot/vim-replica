vim9script

# My python custom stuff
b:ugly_kernel_name = g:ugly_kernels[&filetype]
b:ugly_repl_name = 'IPYTHON'
b:ugly_cell_delimiter = g:ugly_delimiters[&filetype]
b:ugly_run_command = "run -i " .. g:ugly_tmp_filename

# Functions defined for debugging
def CreateHiGroup(): number
    echo "New match ID!"
    # echo ugly_hlgrpID_next
    return matchaddpos("CursorWord0", [1])
enddef

def UpdateHiGroup(ugly_hlgrpID: number): number
    var ugly_hlgrpID_next = uglyrepl#HighlightCell(ugly_hlgrpID, b:ugly_cell_delimiter)
    # echo ugly_hlgrpID_next
    return ugly_hlgrpID_next
enddef


def DeleteHiGroup(ugly_hlgrpID: number)
    matchdelete(ugly_hlgrpID)
    echo "Deleted left match ID!"
enddef

# Init
w:ugly_hlgrpID = 1

# Iteration
augroup highlight_cell
    au!
    # autocmd BufEnter *.py w:ugly_hlgrpID = CreateHiGroup()
    autocmd Bufenter,WinEnter  *.py if !exists("w:ugly_hlgrpID") | CreateHiGroup(w:ugly_hlgrpID) | endif
    autocmd CursorMoved,CursorMovedI *.py w:ugly_hlgrpID = UpdateHiGroup(w:ugly_hlgrpID)
    # We have to separate the events because if the next window has a buffer different than this window
    # then BufLeave and WinLeave will be called in sequence.
    # autocmd BufLeave *.py DeleteHiGroup(w:ugly_hlgrpID)
    autocmd BufLeave,WinLeave *.py if exists("w:ugly_hlgrpID") | DeleteHiGroup(w:ugly_hlgrpID) | endif
augroup END

match Underlined  "# %%" # TODO
