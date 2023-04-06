vim9script


# =======================================
# Functions for sending stuff to the REPL
# =======================================

export def! g:ReplOpen()
    var kernel_name = get(b:, 'sci_kernel_name', g:sci_kernels["default"])
    var repl_name = get(b:, 'sci_repl_name', g:sci_repl_names["default"])
    var size = get(b:, 'sci_repl_size', g:sci_repl_size)
    var direction = g:sci_repl_direction
    # var size = g:sci_repl_size


    # If does not exist => create
    if !bufexists(bufnr('^' .. repl_name .. '$')) # To prevent opening too many buffers with the same name
        if kernel_name == "terminal"
            term_start(&shell, {'term_name': repl_name} )
        else
            term_start("jupyter-console --kernel=" .. kernel_name, {'term_name': repl_name} )
        endif
        setbufvar('^' .. repl_name .. '$', "&buflisted", false)
    else
        # Otherwise display it in a window
        exe "sbuffer " .. bufnr('^' .. repl_name .. '$')
    endif
        # Resize window as per user preference
        exe "wincmd " .. direction
        if size > 0
            if index(["J", "K"], direction ) >= 0
                exe "resize " .. size
            else
                exe "vertical resize " .. size
            endif
        endif
        wincmd p # p = previous
enddef

export def! g:ReplClose()
    var repl_name = get(b:, 'sci_repl_name', g:sci_repl_names["default"])
    var direction = g:sci_repl_direction
    # If you are on a terminal buffer use bd
    if getbufvar(bufnr("%"), '&buftype') == "terminal"
        if index(["J", "K"], direction) >= 0
            b:sci_repl_size = winheight(0)
        else
            b:sci_repl_size = winwidth(0)
        endif
        exe "close"
    else
        # TODO
        var windows_to_close = win_findbuf(bufnr('^' .. repl_name .. '$'))
        # The user may mistakenly open more REPL windows in the same tab.
        # We close all of them.
        for win in windows_to_close
            if index(["J", "K"], direction) >= 0
                b:sci_repl_size = winheight(win)
            else
                b:sci_repl_size = winwidth(win)
            endif
            win_execute(win, "close")
        endfor
    endif
enddef



export def! g:ReplToggle()
    var repl_name = get(b:, 'sci_repl_name', g:sci_repl_names["default"])

    if !empty(win_findbuf(bufnr('^' .. repl_name .. '$')))  || getbufvar(bufnr("%"), '&buftype') == "terminal"
        scirepl#ReplClose()
    else
        scirepl#ReplOpen()
    endif
enddef

export def! g:ReplShutoff(...repl_name_passed: list<string>)
    var repl_name = get(b:, 'sci_repl_name', g:sci_repl_names["default"])
    if !empty(repl_name_passed)
        repl_name = repl_name_passed[0]
    endif

    if bufexists(bufnr('^' .. repl_name .. '$'))
        exe "bw! " .. bufnr('^' .. repl_name .. '$')
    endif
enddef

export def! g:RemoveCells()
    var cell_delimiter = get(b:, 'sci_cells_delimiter', g:sci_cells_delimiters["default"])
    exe ":%g/^" .. cell_delimiter .. "/d"
enddef


export def! g:SendLines(firstline: number, lastline: number)
    var repl_name = get(b:, 'sci_repl_name', g:sci_repl_names["default"])
    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !bufexists(bufnr('^' .. repl_name .. '$'))
        scirepl#ReplOpen()
    endif

    # Actual implementation
    silent exe ":" .. firstline .. "," .. lastline .. "y"
    term_sendkeys(bufnr('^' .. repl_name .. '$'), @")
    norm! j^
enddef


# Actually sending code-cell
export def! g:SendCell()
    var repl_name = get(b:, 'sci_repl_name', g:sci_repl_names["default"])
    # var cell_delimiter = get(g:sci_cells_delimiters, &filetype, g:sci_cells_delimiters["default"])
    var run_command = get(b:, 'sci_run_command', g:sci_run_commands["default"])

    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !bufexists(bufnr('^' .. repl_name .. '$'))
        scirepl#ReplOpen()
    endif

    # Get beginning and end of the cell
    var extremes = scirepl#GetExtremes()
    var line_in = extremes[0]
    var line_out = extremes[1]

    # Jump to the next cell
    cursor(line_out, getcurpos()[2])

    # Write tmp file
    delete(fnameescape(g:sci_tmp_filename)) # Delete tmp file if any
    writefile(getline(line_in, line_out), g:sci_tmp_filename, "a")
    term_sendkeys(bufnr('^' .. repl_name .. '$'), run_command .. "\n")
enddef
#
export def! g:SendFile(...filename: list<string>)
    var file_to_send = expand("%")
    if !empty(filename)
        file_to_send = filename[0]
    endif

    # var tmp_filename = g:sci_tmp_filename
    # var kernel_name = get(g:sci_kernels, &filetype, g:sci_kernels["default"])
    var repl_name = get(b:, 'sci_repl_name', g:sci_repl_names["default"])
    var run_command = get(b:, 'sci_run_command', g:sci_run_commands["default"])

    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !bufexists(bufnr('^' .. repl_name .. '$'))
        scirepl#ReplOpen()
    endif

    # Write tmp file
    delete(fnameescape(g:sci_tmp_filename)) # Delete tmp file if any
    writefile(readfile(fnameescape(file_to_send)), g:sci_tmp_filename, "a")
    term_sendkeys(bufnr('^' .. repl_name .. '$'), run_command .. "\n")
enddef


# Find lines range based on cell_delimiter
export def! g:GetExtremes(display_range: bool = false): list<number>
    var cell_delimiter = get(b:, 'sci_cells_delimiter', g:sci_cells_delimiters["default"])
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
export def! g:HighlightCell(display_range: bool = false)

    var cell_delimiter = get(b:, 'sci_cells_delimiter', g:sci_cells_delimiters["default"])
    var extremes = scirepl#GetExtremes(display_range)
    var line_in = extremes[0]
    var line_out = extremes[1]
    var hlgroup = ""
    var fast = g:sci_fast

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
