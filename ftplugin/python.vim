vim9script

b:repl_kernel_name = g:repl_kernels[&filetype]
b:repl_name = g:repl_names[&filetype]
b:repl_cells_delimiter = g:repl_cells_delimiters[&filetype]
b:repl_run_command = g:repl_run_commands[&filetype]


augroup highlight_cells_python
    autocmd! * <buffer>
    autocmd BufEnter,BufWinEnter,WinEnter,WinLeave <buffer> replica#HighlightCell()
    autocmd CursorMoved,CursorMovedI <buffer> replica#HighlightCell(true)
    # autocmd!
    # autocmd BufEnter,BufWinEnter,WinEnter,WinLeave *.py replica#HighlightCell()
    # autocmd CursorMoved,CursorMovedI *.py replica#HighlightCell(true)
augroup END

# When leaving a buffer of this filetype, then leave the associated repl.
var repl_was_open = get(b:, 'repl_was_open', g:repl_autostart)
var tmp: bool
augroup leave_repl_python
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> tmp = b:repl_was_open | replica#ReplClose() | b:repl_was_open = tmp | echo b:repl_was_open
    autocmd BufWinEnter <buffer> if repl_was_open | replica#ReplOpen() | endif | replica#ReplClose(g:repl_names['default'])
    # autocmd!
    # autocmd BufWinLeave *.py tmp = b:repl_was_open | replica#ReplClose() | b:repl_was_open = tmp | echo b:repl_was_open
    # autocmd BufWinEnter *.py if repl_was_open | replica#ReplOpen() | endif | replica#ReplClose('TERMINAL')
augroup END

# Why <buffer>? Read here: https://vi.stackexchange.com/questions/8056/for-an-autocmd-in-a-ftplugin-should-i-use-pattern-matching-or-buffer
