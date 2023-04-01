vim9script

# My python custom stuff
b:ugly_kernel_name = g:ugly_kernels[&filetype]
b:ugly_repl_name = 'IPYTHON'
b:ugly_cell_delimiter = g:ugly_delimiters[&filetype]
b:ugly_run_command = "run -i " .. g:ugly_tmp_filename

# Functions defined for debugging
def CreateHiGroup(): number
    var ugly_hlgrpID_init = matchaddpos("CursorWord0", [1])
    echom "New match ID:" .. ugly_hlgrpID_init
    return ugly_hlgrpID_init
enddef

def UpdateHiGroup(ugly_hlgrpID: number): number
    var ugly_hlgrpID_next = uglyrepl#HighlightCell(ugly_hlgrpID, b:ugly_cell_delimiter)
    return ugly_hlgrpID_next
enddef


def DeleteHiGroup(ugly_hlgrpID: number)
    matchdelete(ugly_hlgrpID)
    echom "Deleted match ID: " .. ugly_hlgrpID
enddef


# Iteration
augroup highlight_cell
    au!
    # autocmd BufEnter,WinEnter,BufWinEnter *.py if !exists("w:ugly_hlgrpID") | w:ugly_hlgrpID = CreateHiGroup() | endif
    autocmd BufWinEnter  *.py w:ugly_hlgrpID = CreateHiGroup()
    autocmd CursorMoved,CursorMovedI *.py w:ugly_hlgrpID = UpdateHiGroup(w:ugly_hlgrpID)
    # OBS! Vim calls BufLeave and then WinLeave if the next win has another buffer.
    # autocmd BufLeave *.py DeleteHiGroup(w:ugly_hlgrpID)
    # autocmd BufWinLeave *.py if exists("w:ugly_hlgrpID") | DeleteHiGroup(w:ugly_hlgrpID) | endif
    autocmd BufWinLeave *.py  DeleteHiGroup(w:ugly_hlgrpID) | unlet w:ugly_hlgrpID
    # autocmd WinLeave *.py if exists("w:ugly_hlgrpID") | DeleteHiGroup(w:ugly_hlgrpID) | endif
augroup END

match Underlined  "# %%" # TODO
