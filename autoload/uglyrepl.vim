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






export def! g:SendCell(kernel_name: string, repl_name: string, delim: string, run_command: string, tmp_filename: string, shell: string)
    # If the kernel_name is the terminal there is no sense in sending cells of code copied in a
    # TMP file.  Perhaps we could define a default g:run_command_default that align all the lines of
    # TMP separated by &&, e.g. git add -u && git commit -m "foo" && ls ...
    # # TODO
    if kernel_name == "terminal"
        finish # This finish will not work
    endif

    # If there are open terminals with different names than IPYTHON, JULIA, etc. it will open its own
    if !bufexists(repl_name)
         g:Repl(kernel_name, repl_name, shell)
        wincmd h
    endif
    # In Normal mode, go to the next line
    norm! j
    # echo delim
    # In search n is for don't move the cursor, b is backwards and W to don't wrap
    # around
    var line_in = search(delim, 'nbW')
    # We use -1 because we want right-open intervals, i.e. [a,b).
    # Note that here we want the cursor to move to the next cell!
    norm! k
    var line_out = search(delim, 'W') - 1
    if line_out == - 1
        line_out = line("$")
    endif
    # For debugging
    # echo [line_in, line_out]
    delete(fnameescape(tmp_filename))
    writefile(getline(line_in + 1, line_out), tmp_filename, "a")
    #call term_sendkeys(term_list()[0],"run -i ". tmp_filename . "\n")
    # At startup, it is always terminal 2 or the name is hard-coded IPYTHON
    call term_sendkeys(repl_name, run_command .. "\n")
enddef
#
