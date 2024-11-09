vim9script

import autoload "../lib/highlight.vim"
import "../lib/ftcommands_mappings.vim"

# The following variable won't change during run-time
b:kernel_name = g:replica_kernels[&filetype]
b:console_name = g:replica_console_names[&filetype]
b:cells_delimiter = g:replica_cells_delimiters[&filetype]
b:jupyter_console_options = g:replica_jupyter_console_options[&filetype]
b:run_command = g:replica_run_commands[&filetype]

if g:replica_enable_highlight
    augroup highlight_cells
        autocmd! * <buffer>
        autocmd BufEnter,BufWinEnter,WinEnter,WinLeave <buffer> highlight.HighlightCell()
        autocmd CursorMoved,CursorMovedI <buffer> highlight.HighlightCell(true)
    augroup END
endif

# # Why <buffer>? Read here: https://vi.stackexchange.com/questions/8056/for-an-autocmd-in-a-ftplugin-should-i-use-pattern-matching-or-buffer
