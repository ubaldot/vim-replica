vim9script

# ====================================
# State
# ====================================
# Init
var console_geometry = {"python":
            \ {"size": g:replica_console_size,
            \ "position": g:replica_console_direction },
            \ "julia":
            \ {"size": g:replica_console_size,
            \ "position": g:replica_console_direction }
            \  }

var open_buffers = {
            \ "python": [],
            \ "julia": [],
            \ "matlab": [],
            \ "default": []}


# ====================================
# Functions
# ====================================
# ---------------------------------------
# Functions for sending stuff to the REPL
# ---------------------------------------
export def BufferListAdd(ft: string, bufnr: number)
    # if buflisted(bufnr)
  var idx = index(open_buffers[ft], bufnr)

  # If buffer exists, move it to the end, otherwise append it.
  if idx != -1
    # Move buffer to the end
    var item = remove(open_buffers[ft], idx)
    add(open_buffers[ft], item)
  else
    # Append new buffer
    add(open_buffers[ft], bufnr)
  endif
    # endif
    echom "open buffers:" ..  string(open_buffers[&filetype])
enddef

export def BufferListRemove(ft: string, bufnr: number)
  # If the buffer is in the buffer list, then remove it.
  # # TODO Move to the function call in ftplugin
  # var buf_nr = str2nr(expand('<abuf>'))
  var idx = index(open_buffers[ft], bufnr)
  if idx != -1
    remove(open_buffers[ft], idx)
  endif
  echom "removed buffer: " .. string(bufnr)
  echom "open buffers:" ..  string(open_buffers[&filetype])
enddef


export def ReadConsoleGeometry(ft: string)
    # TODO: refactor based on the g:replica_open_buffers list
    # TODO create a resize console function
    exe "wincmd " .. console_geometry[ft]["direction"]
    if size > 0
        if index(["J", "K"], console_geometry[ft]["direction"]) >= 0
            exe "resize " .. console_geometry[ft]["size"]
        else
            exe "vertical resize " .. console_geometry[ft]["size"]
        endif
    endif
    # TODO CHECK
    wincmd p # p = previous, return to the window that open the repl
enddef


# TODO: add WriteConsoleGeometry(), ReadConsoleGeometry()
export def ConsoleOpen()
    # It opens a new console.
    # If the terminal buffer already exists, then it places in a window
    var kernel_name = get(b:, 'kernel_name', g:replica_kernels["default"])
    var console_name = get(b:, 'console_names', g:replica_console_names["default"])
    var size = get(b:, 'console_size', g:replica_console_size)

    # If repl does not exist => create
    if !bufexists(bufnr('^' .. console_name .. '$')) # To prevent opening too many open_buffers with the same name
        if kernel_name == g:replica_console_names["default"]
            term_start(&shell, {'term_name': console_name} )
        else
            term_start("jupyter console --kernel=" .. kernel_name, {'term_name': console_name} )
        endif
        setlocal nobuflisted
        # setbufvar('^' .. console_name .. '$', "&buflisted", false)
    # Otherwise, it exists but if it is hidden.
    # Hence, display it in a window
    elseif !empty(win_findbuf(bufnr('^' .. console_name .. '$')))
        exe "sbuffer " .. bufnr('^' .. console_name .. '$')
    endif

    # The following is executed either if the buffer is newly created
    # or if it is just displayed in a new window.
    # Move and resize window as per user preference (or last user-setting)
enddef

export def ConsoleClose(...replica_name_passed: list<string>)
    # Close the repl, store last size and mark it as closed.
    #
    # If the cursor in on the terminal window, use :bdelete
    var console_name = get(b:, 'console_name', g:replica_console_names["default"])
    if !empty(replica_name_passed)
        # replica_name_passed is a list or arguments
        console_name = replica_name_passed[0]
    endif

    # If user wants to close and he is on the repl
    if getbufvar(bufnr("%"), '&buftype') == 'terminal'
        if index(["J", "K"], g:replica_console_direction) >= 0
            b:replica_console_size = winheight(0)
        else
            b:replica_console_size = winwidth(0)
        endif
        exe "close"
    else
        # The user may mistakenly open more repl windows in the same tab.
        # We close all of them.
        var windows_to_close = win_findbuf(bufnr('^' .. console_name .. '$'))
        # Note that if the buffer does not exist, the for loop is skipped
        # so we don't need to check if the window exist.
        for win in windows_to_close
            # Store the last user-setting
            if index(["J", "K"], g:replica_console_direction) >= 0
                b:replica_console_size = winheight(win)
            else
                b:replica_console_size = winwidth(win)
            endif
            win_execute(win, "close")
        endfor
    endif
    b:replica_is_open = false
enddef



export def ConsoleToggle()

    var console_name = get(b:, 'console_name', g:replica_console_names["default"])
    # TODO: to be improved. repl buffer don't have a variable b:console_name so we need an OR condition
    if !empty(win_findbuf(bufnr('^' .. console_name .. '$')))  || getbufvar(bufnr("%"), '&buftype') == "terminal"
        ConsoleClose()
    else
        ConsoleOpen()
    endif
enddef


export def ConsoleShutoff(...replica_name_passed: list<string>)
    var console_name = get(b:, 'console_name', g:replica_console_names["default"])
    if !empty(replica_name_passed)
        console_name = replica_name_passed[0]
    endif

    if bufexists(bufnr('^' .. console_name .. '$'))
        exe "bw! " .. bufnr('^' .. console_name .. '$')
    endif
enddef

export def RemoveCells()
    var cell_delimiter = get(b:, 'cells_delimiter', g:replica_cells_delimiters["default"])
    exe ":%g/^" .. cell_delimiter .. "/d"
enddef


export def SendLines(firstline: number, lastline: number)
    var console_name = get(b:, 'console_name', g:replica_console_names["default"])

    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    # with a name IPYTHON, JULIA, etc.
    if !bufexists(bufnr('^' .. console_name .. '$'))
        ConsoleOpen()
    endif

    # Actual implementation
    silent exe ":" .. firstline .. "," .. lastline .. "y"
    term_sendkeys(bufnr('^' .. console_name .. '$'), @")
    norm! j^
enddef


# Actually sending code-cell
export def SendCell()
    var console_name = get(b:, 'console_name', g:replica_console_names["default"])
    var run_command = get(b:, 'run_command', g:replica_run_commands["default"])

    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !bufexists(bufnr('^' .. console_name .. '$'))
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
    if !bufexists(bufnr('^' .. console_name .. '$'))
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
        hlgroup = "UbiConsoleHl"
    else
        hlgroup = "UbiConsoleHlFast"
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
