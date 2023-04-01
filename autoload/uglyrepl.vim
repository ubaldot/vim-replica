vim9script

export def! g:Repl(kernel_name: string, repl_name: string, shell: string)
    # Reuse open terminal buffer, if any
    if !bufexists(repl_name)
        if kernel_name == "terminal"
            # exe "botright terminal " .. shell
            term_start(shell, {'term_name': repl_name, 'vertical': v:true} )
        else
             # term_start(kernel_name, {'term_name': repl_name, 'vertical': v:true} )
            term_start("jupyter-console --kernel=" .. kernel_name, {'term_name': repl_name, 'vertical': v:true} )
        endif
    endif
enddef



export def! g:SendLines(firstline: number, lastline: number, kernel_name: string, repl_name: string, shell: string)
    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !bufexists(repl_name)
         uglyrepl#Repl(kernel_name, repl_name, shell)
        wincmd h
    endif
    # Actual implementation
    silent exe ":" .. firstline .. "," .. lastline .. "y"
    term_sendkeys(repl_name, @")
    norm! j^
enddef


# For highlighting and sending cells
export def! g:GetExtremes(cell_delimiter: string): list<number>
    var line_in = search("\^"  .. cell_delimiter, 'cnbW')
    var line_out = search("\^" .. cell_delimiter, 'nW') # The cursor shall not jump when you highlight a cell
    if line_out == 0
        line_out = line("$")
    endif
    echo [line_in, line_out]
    return [line_in, line_out]
enddef


var line_in_old = 0
var line_out_old = 1

export def! g:HighlightCell(hlgrpID_old: number, cell_delimiter: string): number
    var extremes = uglyrepl#GetExtremes(cell_delimiter)
    var line_in = extremes[0]
    var line_out = extremes[1]

    # There is at least one cell
    if line_in != 1 || line_out != line("$")
        # If the cursor moved into another cell recompute the match
        if line_in != line_in_old || line_out != line_out_old
            # echo [line_in, getcurpos()[1], line_out]
            var upper_range = range(0, line_in - 1)
            var lower_range = range(line_out, line("$"))
            var hlgrpID = matchaddpos("CursorWord0", lower_range + upper_range)
            # echo hlgrpID_old
            echo hlgrpID
            matchdelete(hlgrpID_old)
            line_in_old = line_in
            line_out_old = line_out
            return hlgrpID
        endif
        return hlgrpID_old
    else
        return hlgrpID_old
    endif
enddef


# Actually sending code-cell
export def! g:SendCell(kernel_name: string, repl_name: string, cell_delimiter: string, run_command: string, tmp_filename: string, shell: string)
    # If the kernel_name is the terminal there is no sense in sending cells of code copied in a
    # TMP file.  Perhaps we could define a default g:run_command_default that align all the lines of
    # TMP separated by &&, e.g. git add -u && git commit -m "foo" && ls ...
    # # TODO
    if kernel_name == "terminal"
        finish # This finish will not work
    endif
    #%%
    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !bufexists(repl_name)
         uglyrepl#Repl(kernel_name, repl_name, shell)
        wincmd h
    endif

    # Get beginning and end of the cell
    var extremes = uglyrepl#GetExtremes(cell_delimiter)
    var line_in = extremes[0]
    var line_out = extremes[1]

    # Jump to the next cell
    cursor(line_out, getcurpos()[2])

    delete(fnameescape(tmp_filename))
    writefile(getline(line_in, line_out), tmp_filename, "a")
    call term_sendkeys(repl_name, run_command .. "\n")
enddef
#
