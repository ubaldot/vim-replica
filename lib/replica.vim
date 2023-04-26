vim9script

# ====================================
# State
# ====================================
# Init
var console_geometry = {"IPYTHON":
            \ {"width": g:replica_console_width,
            \ "height": g:replica_console_height},
            \  "JULIA":
            \ {"width": g:replica_console_width,
            \ "height": g:replica_console_height}}


var open_buffers = {
            \ "python": [],
            \ "julia": [],
            \ "matlab": [],
            \ "default": []}

export def g:OpenBuffers()
    var open_buffers_ft = get(open_buffers, &filetype, [])
    echo "open buffers:" .. string(open_buffers_ft)
enddef

# ====================================
# Functions
# ====================================
# ---------------------------------------
# Functions for sending stuff to the REPL
# ---------------------------------------
export def BufferListAdd(bufnr: number)
    # if buflisted(bufnr)
  var open_buffers_ft = get(open_buffers, getbufvar(bufnr, '&filetype'), [])
  var idx = index(open_buffers_ft, bufnr)

  # If buffer exists, move it to the end, otherwise append it.
  if idx != -1
    # Move buffer to the end
    var item = remove(open_buffers_ft, idx)
    add(open_buffers_ft, item)
  else
    # Append new buffer
    add(open_buffers_ft, bufnr)
  endif
    # endif
    echom "open buffers:" ..  string(open_buffers_ft)
enddef

export def BufferListRemove(bufnr: number)
  # If the buffer is in the buffer list, then remove it.
  # # TODO Move to the function call in &filetypeplugin
  var open_buffers_ft = get(open_buffers, getbufvar(bufnr, '&filetype'), [])
  echo open_buffers_ft
  var idx = index(open_buffers_ft, bufnr)
  if idx != -1
    remove(open_buffers_ft, idx)
  endif
  echom "removed buffer: " .. string(bufnr)
  echom "open buffers:" ..  string(open_buffers_ft)
enddef

export def ResizeConsoleWindow(console_win_id: number)
    win_execute(console_win_id, 'resize ' .. console_geometry[b:console_name]["height"])
    win_execute(console_win_id, 'vertical resize ' .. console_geometry[b:console_name]["width"])
enddef

export def SaveConsoleWindowSize(console_win_id: number)
    console_geometry[b:console_name]["height"] = winheight(console_win_id)
    console_geometry[b:console_name]["width"] = winwidth(console_win_id)
enddef


export def ConsoleExists(): bool
    # It only say if a console is in the buffer list
    # but not if it is in any window.
    if IsFiletypeSupported()
        return bufexists(bufnr('^' .. b:console_name .. '$'))
    else
        return false
    endif
enddef

export def ConsoleWinID(): list<number>
    # Return the windows ID where the console is displayed.
    if IsFiletypeSupported()
        return win_findbuf(bufnr('^' .. b:console_name .. '$'))
    else
        return []
    endif
enddef


export def IsFiletypeSupported(): bool
    return exists("b:kernel_name")
enddef


export def ConsoleOpen()
    # If console does not exist, then create one,
    # otherwise, if it is hidden, just display it.
    if IsFiletypeSupported()
        if !ConsoleExists()
            win_execute(win_getid(), 'term_start("jupyter console --kernel=" .. b:kernel_name, {"term_name": b:console_name})' )
        elseif empty(ConsoleWinID())
            win_execute(win_getid(), 'sbuffer ' .. bufnr('^' .. b:console_name .. '$'))
        endif

        # Set few options
        var console_win_id = win_findbuf(bufnr('$'))[0]
        win_execute(console_win_id, 'wincmd ' .. g:replica_console_position)
        win_execute(console_win_id, 'setlocal nobuflisted winminheight winminwidth')
        # Set geometry
        ResizeConsoleWindow(console_win_id)
    endif
enddef


export def ConsoleClose()
    for win in ConsoleWinID()
        SaveConsoleWindowSize(win)
        win_execute(win, "close")
    endfor
enddef


export def g:ConsoleToggle()
    if empty(ConsoleWinID())
        ConsoleOpen()
    else
        ConsoleClose()
    endif
enddef


export def g:ConsoleWipeout()
    if ConsoleExists()
        exe "bw! " .. bufnr('^' .. b:console_name .. '$')
    endif
enddef


export def RemoveCells()
    if IsFiletypeSupported()
        exe ":%g/^" .. b:cell_delimiter .. "/d _"
    endif
enddef


export def SendLines(firstline: number, lastline: number)
    var console_name = get(b:, 'console_name', g:replica_console_names["default"])

    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    # with a name IPYTHON, JULIA, etc.
    if !ConsoleExists()
        ConsoleOpen()
    endif

    # Actual implementation
    silent exe ":" .. firstline .. "," .. lastline .. "y"
    term_sendkeys(bufnr('^' .. b:console_name .. '$'), @")
    norm! j^
enddef


# Actually sending code-cell
export def SendCell()
    var console_name = get(b:, 'console_name', g:replica_console_names["default"])
    var run_command = get(b:, 'run_command', g:replica_run_commands["default"])

    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !ConsoleExists()
        ConsoleOpen()
    endif

    # Get beginning and end of the cell
    var extremes = GetExtremes()
    var line_in = extremes[0]
    var line_out = extremes[1]

    # Jump to the next cell
    cursor(line_out, getcurpos()[2])

    # Write tmp file
    delete(fnameescape(g:replica_tmp_filename)) # Delete tmp file if any
    writefile(getline(line_in, line_out), g:replica_tmp_filename, "a")
    term_sendkeys(bufnr('^' .. console_name .. '$'), run_command .. "\n")
enddef


export def SendFile(...filename: list<string>)
    var file_to_send = expand("%")
    if !empty(filename)
        file_to_send = filename[0]
    endif
    var console_name = get(b:, 'console_name', g:replica_console_names["default"])
    var run_command = get(b:, 'run_command', g:replica_run_commands["default"])

    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !ConsoleExists()
        ConsoleOpen()
    endif

    # Write tmp file
    delete(fnameescape(g:replica_tmp_filename)) # Delete tmp file if any
    writefile(readfile(fnameescape(file_to_send)), g:replica_tmp_filename, "a")
    term_sendkeys(bufnr('^' .. console_name .. '$'), run_command .. "\n")
enddef


# Find lines range based on cell_delimiter
export def GetExtremes(display_range: bool = false): list<number>
    var cell_delimiter = get(b:, 'cells_delimiter', g:replica_cells_delimiters["default"])
    var line_in = search("\^"  .. cell_delimiter, 'cnbW')
    var line_out = search("\^" .. cell_delimiter, 'nW')
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


# ---------------------------------------
# Functions for highlighing cells
# ---------------------------------------
sign define ReplicaConsoleHl text=- linehl=CursorLine
sign define ReplicaConsoleHlFast text=- linehl=UnderLined

var line_in_old = 1
var line_out_old = line("$")
var list_sign_id_old = []
var list_sign_id = []


# var counter_dbg = 0
# When adding a sign keep in mind that we set sign_id = line number
export def HighlightCell(display_range: bool = false)

    var cell_delimiter = get(b:, 'cells_delimiter', g:replica_cells_delimiters["default"])
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
        # ...and if the cursor moved into another cell, then update the signs
        if line_in != line_in_old || line_out != line_out_old
            # counter_dbg = counter_dbg + 1
            # echo counter_dbg

            # Remove existing signs related to ReplicaConsoleHl
            if !empty(list_sign_id_old)
                for line in list_sign_id_old
                    sign_unplace("", {"buffer": expand("%:p"), "id": line})
                endfor
            endif


            # Find lines
            if g:replica_alt_highlight == false
                # Case Slow
                list_sign_id = range(1, line_in - 1) + range(line_out, line("$"))
            else
                # exe ":g/" .. b:replica_cell_delimiter .. "/add(list_sign_id, line('.')"
                list_sign_id = [line_in, line_out]
            endif

            # Place signs and move current values to _old
            list_sign_id_old = []
            for line in list_sign_id
                sign_place(line, "", hlgroup, expand("%:p"), {"lnum": line})
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
