vim9script
# ---------------------------------------
# Functions for highlighing cells
# ---------------------------------------
sign define ReplicaConsoleHl  linehl=CursorLine
sign define ReplicaConsoleHlFast  linehl=UnderLined

var line_in_old = 1
var line_out_old = line("$")
var list_sign_id_old = []
var list_sign_id = []


# Find lines range based on cell_delimiter
export def GetExtremes(display_range: bool = false): list<number>
    var line_in = search("\^"  .. b:cells_delimiter, 'cnbW')
    var line_out = search("\^" .. b:cells_delimiter, 'nW')
    # If search() returns 0 it means that the pattern has not been found
    if line_in == 0
        line_in = 1
    endif
    if line_out == 0
        line_out = line("$")
    endif
    # Display range only if some cell has been found
    if (line_in != 1 || line_out != line("$")) && display_range
        echo "cell_range=[" .. line_in .. "," .. line_out .. "]"
    endif
    return [line_in, line_out]
enddef

# var counter_dbg = 0
# When adding a sign keep in mind that we set sign_id = line number
# TODO: lines are shaded through sign feature, but this also add a small sign
# next by the line numbers which is not super nice. Is there any other
# alternative to sign for shading lines?
export def HighlightCell(display_range: bool = false)
    var extremes = GetExtremes(display_range)
    var line_in = extremes[0]
    var line_out = extremes[1]
    var hlgroup = ""

    if g:replica_alt_highlight == false
        hlgroup = "ReplicaConsoleHl"
    else
        hlgroup = "ReplicaConsoleHlFast"
    endif
    # There is at least one cell
    if line_in != 1 || line_out != line("$")
        # if the cursor moved into another cell, then update the signs
        if line_in != line_in_old || line_out != line_out_old
            # counter_dbg = counter_dbg + 1
            # echo counter_dbg
            # Remove existing signs related to ReplicaConsoleHl
            if !empty(list_sign_id_old)
                for line in list_sign_id_old
                    sign_unplace("", {"buffer": expand("%:p"),
                                \ "id": line})
                endfor
            endif
            # Find lines
            if g:replica_alt_highlight == false
                # Case Slow
                list_sign_id = range(1, line_in - 1)
                            \ + range(line_out, line("$"))
            else
                list_sign_id = [line_in, line_out]
            endif
            # Place signs and move current values to _old
            # TODO: avoid highlighting the last line of the buffer
            # when the cursor is in the last cell
            list_sign_id_old = []
            for line in list_sign_id
                sign_place(line, "", hlgroup, expand("%:p"),
                            \ {"lnum": line})
                add(list_sign_id_old, line)
            endfor
            # Update old values
            line_in_old = line_in
            line_out_old = line_out
        endif
    else
        # ..which means line_in = 1 and line_out = line("$")
        # i.e. if there are no cells left remove all the signs
        for line in list_sign_id_old
            sign_unplace("", {"buffer": expand("%:p"), "id": line})
        endfor
    endif
enddef
