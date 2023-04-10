vim9script

b:repl_kernel_name = g:repl_kernels[&filetype]
b:repl_name = g:repl_names[&filetype]
b:repl_cells_delimiter = g:repl_cells_delimiters[&filetype]
b:repl_run_command = g:repl_run_commands[&filetype]


augroup highlight_cells_python
    autocmd! * <buffer>
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave <buffer> replica#HighlightCell()
    autocmd CursorMoved,CursorMovedI <buffer> replica#HighlightCell(true)
augroup END


def BufferListAdd()
    if buflisted(bufnr())
      # If buffer exists, move it to the end, otherwise append it.
      var idx = index(g:repl_open_buffers[&filetype], bufnr())

      if idx != -1
        var item = remove(g:repl_open_buffers[&filetype], idx)
        add(g:repl_open_buffers[&filetype], item)
      else
        add(g:repl_open_buffers[&filetype], bufnr())
      endif
    endif
enddef

def BufferListRemove()
  # If the buffer is in the buffer list, then remove it.
  var buf_nr = str2nr(expand('<abuf>'))
  var idx = index(g:repl_open_buffers[&filetype], buf_nr)
  if idx != -1
    remove(g:repl_open_buffers[&filetype], idx)
  endif
enddef

def Startup(): bool
    # Here we decide what shall we do when entering a python file
    var do_open = false
    # If the previous buffer exists and its filetype was Python
    # just copy its repl status (open or close)
    # if len(g:repl_open_buffers[&filetype]) > 1
    if !empty(g:repl_open_buffers[&filetype])
        # Obs! g:repl_open_buffers[&filetype][-1] is the current buffer!
        var prev_buf_nr = g:repl_open_buffers[&filetype][-1]
        echo "prev_buf: " .. bufname(prev_buf_nr) ..  ", prev_repl_ is open: " .. getbufvar(prev_buf_nr, 'repl_is_open')
        do_open = getbufvar(prev_buf_nr, 'repl_is_open')
    else
        echo "pluto"
        do_open = g:repl_autostart
    endif
    return do_open
enddef


var tmp = 0
augroup leave_repl_python
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> tmp = b:repl_is_open | replica#ReplClose() | b:repl_is_open = tmp # Hop to keep the buffer status because replica#Close() set repl_is_open = 0
    autocmd BufWinEnter <buffer> if Startup() | replica#ReplOpen() | else | replica#ReplClose() | endif | BufferListAdd()
    autocmd BufDelete,BufWipeout <buffer> BufferListRemove()
augroup END

# Why <buffer>? Read here: https://vi.stackexchange.com/questions/8056/for-an-autocmd-in-a-ftplugin-should-i-use-pattern-matching-or-buffer
