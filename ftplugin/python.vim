vim9script

# My python custom stuff
b:ugly_kernel_name = g:ugly_kernels[&filetype]
b:ugly_repl_name = 'IPYTHON'
b:ugly_cell_delimiter = g:ugly_delimiters[&filetype]
b:ugly_run_command = "run -i " .. g:ugly_tmp_filename

# Functions for handling highlights.
# Highlights are windows properties, not buffer!
# We want that for each *py window there is ONLY one highlight group
# If a window does not contain any *.py files, then :echo getmatches() shall return []
def CreateHiGroup(): number
    var ugly_hlgrpID_init = matchaddpos("CursorWord0", [1])
    # echom "New match ID: " .. ugly_hlgrpID_init
    # echom getmatches()
    return ugly_hlgrpID_init
enddef

def UpdateHiGroup(ugly_hlgrpID: number): number
    var ugly_hlgrpID_next = uglyrepl#HighlightCell(ugly_hlgrpID, b:ugly_cell_delimiter)
    # echom getmatches()
    return ugly_hlgrpID_next
enddef


def DeleteHiGroup(ugly_hlgrpID: number)
    matchdelete(ugly_hlgrpID)
    # echom "Deleted match ID: " .. ugly_hlgrpID
    # echom getmatches()
enddef

def ClearMatches()
    clearmatches()
    # echom getmatches()
    # echom "Cleared all matches!"
enddef


# Iteration
augroup highlight_cells
    au!
    # WinEnter = WinEnter + BufEnter, therefore every time you jump in a new
    # windows that contains a python file CreateHiGroup() is called twice!
    # Also when you open in split with NERDTree weird things happen.
    # Hence, upon WimEnter (in a python file) we just take the last highlight group
    autocmd WinEnter  *.py  w:ugly_hlgrpID = CreateHiGroup()
    autocmd BufEnter  *.py w:ugly_hlgrpID = CreateHiGroup()
    autocmd CursorMoved,CursorMovedI *.py w:ugly_hlgrpID = UpdateHiGroup(w:ugly_hlgrpID)
    # Consider restoring the DeleteHiGroup thing
    # autocmd BufLeave *.py  DeleteHiGroup(w:ugly_hlgrpID)
    # autocmd WinLeave *.py  DeleteHiGroup(w:ugly_hlgrpID)
    #
    # BruteForce method: can be improved!
    autocmd BufLeave *.py  ClearMatches() | unlet w:ugly_hlgrpID
    autocmd WinLeave *.py  ClearMatches()
augroup END

match Underlined  "# %%" # TODO
