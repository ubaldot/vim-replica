vim9script

import autoload "../lib/highlight.vim"
# ====================================
# State
# ====================================
# Init
var console_geometry = {"width": g:replica_console_width,
            \ "height": g:replica_console_height}


# ====================================
# Functions
# ====================================
# ---------------------------------------
# Functions for sending stuff to the REPL
# ---------------------------------------

def ResizeConsoleWindow(console_win_id: number)
    win_execute(console_win_id, 'resize ' .. console_geometry["height"])
    win_execute(console_win_id, 'vertical resize '
                \ .. console_geometry["width"])
enddef

def SaveConsoleWindowSize(console_win_id: number)
    console_geometry["height"] = winheight(console_win_id)
    console_geometry["width"] = winwidth(console_win_id)
enddef


def ConsoleExists(): bool
    # It only say if a console of this type is in the buffer list
    # but not if it is in any window.
    if exists("b:console_name")
        return bufexists(bufnr('^' .. b:console_name .. '$'))
    # In case you are on a console, then b:console_name does not exists,
    # therefore you have to check if it is a terminal with some console name.
    elseif getbufvar(bufnr(), '&buftype') == "terminal"
          \ && index(values(g:replica_console_names), bufname("%")) != -1
        return true
    else
        return false
    endif
enddef

def ConsoleWinID(): list<number>
    # Return the windows ID where the console is displayed.
    # OBS! b:console_name does not exist for terminal windows!
    if ConsoleExists()
        if getbufvar(bufnr("%"), '&buftype') == "terminal"
                \ && index(values(g:replica_console_names), bufname("%")) != -1
            # If we are on a console, then the current buffer is the console
            return win_findbuf(bufnr())
        else
            return win_findbuf(bufnr('^' .. b:console_name .. '$'))
        endif
    else
        return []
    endif
enddef


def IsFiletypeSupported(): bool
    return !empty(getbufvar('%', "kernel_name"))
enddef


def ConsoleOpen()
    # If console does not exist, then create one,
    # otherwise, if it is hidden, just display it.
    var console_win_id = 0
    if IsFiletypeSupported()
        if !ConsoleExists()
            var start_cmd = $"jupyter console --kernel={b:kernel_name} "
                        \ .. b:jupyter_console_options
            setwinvar(win_getid(), 'start_cmd', start_cmd)
            win_execute(win_getid(), 'term_start(w:start_cmd,
                        \ {"term_name": b:console_name})' )
            console_win_id = win_findbuf(bufnr('$'))[0]
        elseif empty(ConsoleWinID())
            win_execute(win_getid(), 'sbuffer '
                        \ .. bufnr('^' .. b:console_name .. '$'))
            console_win_id = win_findbuf(bufnr('^'
                        \ .. b:console_name .. '$'))[0]
        endif

        # Set few options
        win_execute(console_win_id, 'wincmd ' .. g:replica_console_position)
        win_execute(console_win_id, 'setlocal nobuflisted winminheight
                    \ winminwidth')
        # Set geometry
        ResizeConsoleWindow(console_win_id)
    endif
enddef


def ConsoleClose()
    # TODO Modify and make all the REPL to close from wherever you are
    # if IsFiletypeSupported() || getbufvar(bufnr(), '&buftype') == "terminal"
    if IsFiletypeSupported()
        for win in ConsoleWinID()
            SaveConsoleWindowSize(win)
            win_execute(win, "close")
        endfor
    endif
enddef


export def ConsoleToggle()
    # if IsFiletypeSupported() || getbufvar(bufnr(), '&buftype') == "terminal"
    if IsFiletypeSupported()
        if empty(ConsoleWinID())
            ConsoleOpen()
        else
            ConsoleClose()
        endif
    endif
enddef


export def ConsoleShutoff()
    for win in ConsoleWinID()
        SaveConsoleWindowSize(win)
        exe "bw! " .. winbufnr(win)
    endfor
enddef


export def RemoveCells()
    if IsFiletypeSupported()
        for ii in range(1, line('$'))
            if getline(ii) =~ "^" .. b:cells_delimiter
                deletebufline('%', ii)
            endif
        endfor
    else
        echo "vim-replica: filetype not supported!"
    endif
enddef


export def SendLines(firstline: number, lastline: number)
    if IsFiletypeSupported()
        if !ConsoleExists()
            ConsoleOpen()
        endif

        # Actual implementation
        for line in getline(firstline, lastline)
            term_sendkeys(bufnr('^' .. b:console_name .. '$'), line .. "\n")
        endfor
        # TODO: avoid the following when firstline and lastline are passed
        norm! j^
    else
        echo "vim-replica: filetype not supported!"
    endif
enddef


# Actually sending code-cell
export def SendCell()
    if IsFiletypeSupported()
        if !ConsoleExists()
            ConsoleOpen()
        endif
        # Get beginning and end of the cell
        var extremes = highlight.GetExtremes()
        var line_in = extremes[0]
        var line_out = extremes[1]
        # Jump to the next cell
        cursor(line_out, getcurpos()[2])
        # Write tmp file
        delete(fnameescape(g:replica_tmp_filename)) # Delete tmp file if any
        writefile(getline(line_in, line_out), g:replica_tmp_filename, "a")
        term_sendkeys(bufnr('^' .. b:console_name .. '$'),
                    \ b:run_command .. "\n")
    else
        echo "vim-replica: filetype not supported!"
    endif
enddef



export def SendFile(...filename: list<string>)
    # TODO: too many Ex commands.
    if !empty(filename)
        exe ":edit " ..  fnameescape(filename[0])
    endif

    if IsFiletypeSupported()
        # If there are open terminals with different names than IPYTHON,
        # JULIA, etc. it will open its own
        if !ConsoleExists()
            ConsoleOpen()
        endif
        # Write tmp file
        delete(fnameescape(g:replica_tmp_filename)) # Delete tmp file if any
        writefile(getline(1, '$'), g:replica_tmp_filename, "a")
        term_sendkeys(bufnr('^' .. b:console_name .. '$'),
                    \ b:run_command .. "\n")
    else
        echo "vim-replica: filetype not supported!"
    endif

    # Remove temp buffer
    if !empty(filename)
        exe ":bprev"
        exe "bw! " .. fnameescape(filename[0])
    endif
enddef
