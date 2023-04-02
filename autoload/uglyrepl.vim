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
    var line_out = search("\^" .. cell_delimiter, 'nW')
    # If search returns 0 it means that the pattern has not been found
    if line_in == 0
        line_in = 1
    endif
    if line_out == 0
        line_out = line("$")
    endif
    # if line_in != 1 || line_out != line("$")
    #     echo "cell_range=[" .. line_in ", " .. line_out .. "]\n"
    # endif
    return [line_in, line_out]
enddef



# for highlightning cells
sign define UglyReplHl text=- linehl=CursorLine
sign define UglyReplHlFast text=- linehl=UnderLine

var line_in_old = 1
var line_out_old = line("$")

# Specific for g:HighlightCell function
# var list_all_signs = sign_getplaced(expand("%:p"))[0]['signs']
var list_sign_id_old = []
# for s in list_all_signs
#     if s['name'] == "UglyReplHl"
#         add(list_sign_id_old, s['lnum'])
#     endif
# endfor

# When adding a sign keep in mind that we set sign_id = line number
export def! g:HighlightCell(cell_delimiter: string)
    var extremes = uglyrepl#GetExtremes(cell_delimiter)
    var line_in = extremes[0]
    var line_out = extremes[1]
    var go_fast = 0
    var upper_range = []
    var lower_range = []

    # There is at least one cell
    if line_in != 1 || line_out != line("$")
        # ...and if the cursor moved into another cell,
        # then update the highlight recompute the match
        if line_in != line_in_old || line_out != line_out_old

            # Remove existing signs related to UglyReplHl
            if !empty(list_sign_id_old)
                for line in list_sign_id_old
                    sign_unplace("", {"buffer": expand("%:p"), "id": line})
                endfor
            endif

            # Cleanup old list
            list_sign_id_old = []

            if go_fast == 0
                # Case Slow
                upper_range = range(1, line_in - 1)
                lower_range = range(line_out, line("$"))

                for line in upper_range + lower_range
                    sign_place(line, "", "UglyReplHl", expand("%:p"), {"lnum": line})
                    add(list_sign_id_old, line)
                endfor
            else
                # Case Fast
                var list_sign_id = []
                # exe ":g/" .. b:ugly_cell_delimiter .. "/add(" .. list_sign_id ..  ", line('.'))"
                exe ":g/" .. b:ugly_cell_delimiter .. "/add(" .. list_sign_id .. ", line('.'))"

                for line in list_sign_id
                    sign_place(line, "", "UglyReplHlFast", expand("%:p"), {"lnum": line})
                    add(list_sign_id_old, line)
                endfor
            endif
        endif
    else
        # If there are no cells left remove all the signs
        for line in list_sign_id_old
            sign_unplace("", {"buffer": expand("%:p"), "id": line})
        endfor
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
