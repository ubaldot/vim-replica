vim9script

# =======================================
# Functions for sending stuff to the REPL
# =======================================

export def! g:ReplOpen(kernel_name: string, repl_name: string, direction: string, size: number)
    # If not already opened
    if !bufexists(bufnr('^' .. repl_name .. '$')) # To prevent opening too many buffers with the same name
        if kernel_name == "terminal"
            term_start(&shell, {'term_name': repl_name} )
        else
            term_start("jupyter-console --kernel=" .. kernel_name, {'term_name': repl_name} )
        endif
    endif
        setbufvar('^' .. repl_name .. '$', "&buflisted", false)
        exe "wincmd " .. direction
        if size > 0
            exe "resize " .. size
        endif
        wincmd p # p = previous
enddef


export def! g:ReplToggle(kernel_name: string, repl_name: string, direction: string, size: number)
    # If repl (terminal) buffer does not exists create one
    if !bufexists(bufnr('^' .. repl_name .. '$'))
        scirepl#ReplOpen(kernel_name, repl_name, direction, size)
    elseif !empty(win_findbuf(bufnr('^' .. repl_name .. '$'))) # match-case repl_name
        var windows_to_close = win_findbuf(bufnr('^' .. repl_name .. '$'))
        for win in windows_to_close
            win_execute(win, "close")
        endfor
    # Otherwise, if repl exists but it is not displayed in any window
    else
        # Same as in ReplOpen
        exe "sbuffer " .. bufnr('^' .. repl_name .. '$')
        exe "wincmd " .. direction
        if size > 0
            exe "resize " .. size
        endif
        wincmd p # p = previous
    endif
enddef

export def! g:ReplShutoff(repl_name: string)
    if bufexists(bufnr('^' .. repl_name .. '$'))
        exe "bw! " .. bufnr('^' .. repl_name .. '$')
    endif
enddef

export def! g:RemoveCells(cell_delimiter: string)
    exe ":%g/^" .. cell_delimiter .. "/d"
enddef


export def! g:SendLines(firstline: number, lastline: number, kernel_name: string, repl_name: string, direction: string, size: number)
    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !bufexists(bufnr('^' .. repl_name .. '$'))
        scirepl#ReplOpen(kernel_name, repl_name, direction, size)
    endif

    # Actual implementation
    silent exe ":" .. firstline .. "," .. lastline .. "y"
    term_sendkeys(bufnr('^' .. repl_name .. '$'), @")
    norm! j^
enddef


# Actually sending code-cell
export def! g:SendCell(kernel_name: string, repl_name: string, cell_delimiter: string, run_command: string, tmp_filename: string, direction: string, size: number)
    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !bufexists(bufnr('^' .. repl_name .. '$'))
        scirepl#ReplOpen(kernel_name, repl_name, direction, size)
    endif

    # Get beginning and end of the cell
    var extremes = scirepl#GetExtremes(cell_delimiter)
    var line_in = extremes[0]
    var line_out = extremes[1]

    # Jump to the next cell
    cursor(line_out, getcurpos()[2])

    # Write tmp file
    delete(fnameescape(tmp_filename)) # Delete tmp file if any
    writefile(getline(line_in, line_out), tmp_filename, "a")
    term_sendkeys(bufnr('^' .. repl_name .. '$'), run_command .. "\n")
enddef
#
export def! g:SendFile(kernel_name: string, repl_name: string, run_command: string, tmp_filename: string, direction: string, size: number)
    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    scirepl#ReplOpen(kernel_name, repl_name, direction, size)

    # Write tmp file
    delete(fnameescape(tmp_filename)) # Delete tmp file if any
    writefile(getline(1, line("$")), tmp_filename, "a")
    term_sendkeys(bufnr('^' .. repl_name .. '$'), run_command .. "\n")
enddef


# Find lines range based on cell_delimiter
export def! g:GetExtremes(cell_delimiter: string, display_range: bool = false): list<number>
    var line_in = search("\^"  .. cell_delimiter, 'cnbW')
    var line_out = search("\^" .. cell_delimiter, 'nW')
    # If search returns 0 it means that the pattern has not been found
    if line_in == 0
        line_in = 1
    endif
    if line_out == 0
        line_out = line("$")
    endif
    if (line_in != 1 || line_out != line("$")) && display_range
        echo "cell_range=[" .. line_in .. "," .. line_out .. "]"
    endif
    return [line_in, line_out]
enddef


# ======================================
# Functions for highlighing cells
# ======================================

# for highlightning cells
sign define SciReplHl text=- linehl=CursorLine
sign define SciReplHlFast text=- linehl=UnderLined

var line_in_old = 1
var line_out_old = line("$")
var list_sign_id_old = []
var list_sign_id = []


# When adding a sign keep in mind that we set sign_id = line number
export def! g:HighlightCell(cell_delimiter: string, fast: bool, display_range: bool = false)
    var extremes = scirepl#GetExtremes(cell_delimiter, display_range)
    var line_in = extremes[0]
    var line_out = extremes[1]
    var hlgroup = ""

    if fast == false
        hlgroup = "SciReplHl"
    else
        hlgroup = "SciReplHlFast"
    endif

    # There is at least one cell
    if line_in != 1 || line_out != line("$")
        # ...and if the cursor moved into another cell,
        # then update the highlight recompute the match
        if line_in != line_in_old || line_out != line_out_old

            # Remove existing signs related to SciReplHl
            if !empty(list_sign_id_old)
                for line in list_sign_id_old
                    sign_unplace("", {"buffer": expand("%:p"), "id": line})
                endfor
            endif

            # Cleanup old list
            list_sign_id_old = []

            # Find lines
            if fast == false
                # Case Slow
                list_sign_id = range(1, line_in - 1) + range(line_out, line("$"))
            else
                # exe ":g/" .. b:sci_cell_delimiter .. "/add(list_sign_id, line('.')"
                list_sign_id = [line_in, line_out]
            endif

            # Place signs
            for line in list_sign_id
                sign_place(line, "", hlgroup, expand("%:p"), {"lnum": line})
                add(list_sign_id_old, line)
            endfor
        endif
    else
        # If there are no cells left remove all the signs
        for line in list_sign_id_old
            sign_unplace("", {"buffer": expand("%:p"), "id": line})
        endfor
    endif
enddef
