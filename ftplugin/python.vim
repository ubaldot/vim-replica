vim9script

import autoload "../lib/replica.vim"

b:replica_kernel_name = g:replica_kernels[&filetype]
b:replica_name = g:replica_names[&filetype]
b:replica_cells_delimiter = g:replica_cells_delimiters[&filetype]
b:replica_run_command = g:replica_run_commands[&filetype]


augroup highlight_cells_python
    autocmd! * <buffer>
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave <buffer> replica.HighlightCell()
    autocmd CursorMoved,CursorMovedI <buffer> replica.HighlightCell(true)
augroup END


def BufferListAdd()
    if buflisted(bufnr())
      # If buffer exists, move it to the end, otherwise append it.
      var idx = index(g:replica_open_buffers[&filetype], bufnr())

      if idx != -1
        var item = remove(g:replica_open_buffers[&filetype], idx)
        add(g:replica_open_buffers[&filetype], item)
      else
        add(g:replica_open_buffers[&filetype], bufnr())
      endif
    endif
enddef

def BufferListRemove()
  # If the buffer is in the buffer list, then remove it.
  var buf_nr = str2nr(expand('<abuf>'))
  var idx = index(g:replica_open_buffers[&filetype], buf_nr)
  if idx != -1
    remove(g:replica_open_buffers[&filetype], idx)
  endif
enddef

def Startup(): bool
    # Here we decide what shall we do when entering a python file
    var do_open = false
    echo "I triggered Startup() function!"
    # If the previous buffer exists and its filetype was Python
    # just copy its repl status (open or close)
    # if len(g:replica_open_buffers[&filetype]) > 1
    if !empty(g:replica_open_buffers[&filetype])
        # Obs! g:replica_open_buffers[&filetype][-1] is the current buffer!
        var prev_buf_nr = g:replica_open_buffers[&filetype][-1]
        # echo "prev_buf: " .. bufname(prev_buf_nr) ..  ", prev_replica_ is open: " .. getbufvar(prev_buf_nr, 'replica_is_open')
        do_open = getbufvar(prev_buf_nr, 'replica_is_open')
    else
        echo "pluto"
        do_open = g:replica_autostart
    endif
    return do_open
enddef


var tmp = 0
augroup leave_replica_python
    autocmd! * <buffer>
    # TODO: problem b:replica_is_open not defined
    # When you have two windows (one python and one non-python) and then you make full screen the non-python window.
    # i.e. leaving a *py window from a non-py window.
    autocmd BufWinLeave <buffer> tmp = b:replica_is_open | replica.ConsoleClose() | b:replica_is_open = tmp # Hop to keep the buffer status because replica.Close() set replica_is_open = false
    # If Startup() say it is OK to open, then open, otherwise close.
    autocmd BufWinEnter <buffer> if Startup() | replica.ConsoleOpen() | else | replica.ConsoleClose() | endif | BufferListAdd()
    autocmd BufDelete,BufWipeout <buffer> BufferListRemove()
augroup END

# Why <buffer>? Read here: https://vi.stackexchange.com/questions/8056/for-an-autocmd-in-a-ftplugin-should-i-use-pattern-matching-or-buffer
