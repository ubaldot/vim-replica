# **REPL**ica.vim
REPL for Scientific applications.

<p align="center">
<img src="/OutlineDemo.gif" width="60%" height="60%">
</p>

## Introduction
Replica allows the utilization of any REPL programs (Python, Julia, etc.)
inside Vim in a seamless way.

Replica supports the following key features:

1. Sending lines, files and code-cells to a REPL,
2. Code-cells highlighting.

Each REPL is a jupyter-console initiated with a specific kernel running in a
*terminal* buffer.  For each *filetype* replica provides you with one
available REPL to send text in.

You can work with many REPL:s for different languages at the same time.
Based on the current buffer *filetype* replica will send text in the
appropriate REPL automatically.

I wrote vim-replica because I never managed to make vim-slime to work
satisfactory under Windows and vim-REPL crashes too often when using the
toggle function.

## Requirements
Replica is written in Vim9script, and you need at least Vim 9.0.
Furthermore, you need jupyter console to make replica to work with the
associated kernels that you need for your specific language.

You can google to discover the available jupyter kernels out there whereas you
can run `jupyter kernelspec list` from the command line of your terminal to
see the list of kernels installed on your machine.

See jupyter console docs for more information.

## Usage
#### Commands
`:ReplicaConsoleToggle`     - un-hide and hide the REPL.

`:ReplicaConsoleRestart`    - restart the REPL.

`:ReplicaConsoleShutoff`    - wipeout the buffer associated to the REPL.

`:[range]ReplSendLines`     - send the lines in [range] to the REPL.

`:ReplicaSendCell`          - send the current code-cell.

`:ReplicaSendFile [{file}]` - send {file} to the REPL.

`:ReplicaRemoveCells`       - remove all the cells from the current buffer.

> **Warning**
> The commands work only if they are run from a buffer whose *filetype* is
> supported.

#### Mappings
```
# Default mappings
nnoremap <F2> <Plug>ReplicaConsoleToggle
inoremap <F2> <Plug>ReplicaConsoleToggle
tnoremap <F2> <c-w><Plug>ReplicaConsoleToggle

nnoremap <F9> <Plug>ReplicaSendLines
inoremap <F9> <Plug>ReplicaSendLines
xnoremap <F9> <Plug>ReplicaSendLines

nnoremap <F5> <Plug>ReplicaSendFile
inoremap <F5> <Plug>ReplicaSendFile

nnoremap <c-enter> <Plug>ReplicaSendCell
inoremap <c-enter> <Plug>ReplicaSendCell
```

## Basic Configuration
```
# Default values
g:replica_enable_highlight = true
g:replica_console_position = L
g:replica_console_width = floor(&columns/2)
g:replica_console_width = &lines
g:replica_kernels = {"python": "python3",
                   \ "julia": "julia-1.8"}
g:replica_cells_delimiters = { "python": "# %%",
                             \ "julia": "# %%"}
```

## Add new languages
At the moment vim-replica only support python and julia languages.
However, vim-eplica is nicely extendable and adding new languages is easy.

Say that a new language is associated to a certain *filetype*.
Then, you can add it to replica in two steps:

1. Add a new key-value pair to the `g:replica_kernels`, `g:replica_names`,
  `g:replica_cells_delimiters` and `g:replica_run_commands` dictionaries.
2. Duplicate any existing vim-replica/ftplugin/*.vim file and rename it
   according to the newly included *filetype*.

Done!

> *Note*
> You may use the global `ftplugin` folder but it has not been tested yet.

## Troubleshooting

Q. My Vim became very slow!
A. You can try to set |g:replica_alt_highlight| = true in your *vimrc*.
Or, if it is still very slow, you can try to completely disable the cells
highlighting by setting |g:replica_enable_highlight| to false.

Q. Is it possible to copy from a REPL to a buffer?
A. Yes! If you <c-w>N in your REPL, then it becomes just an ordinary buffer.
There you can yank everything you want.
To re-enable the REPL just press i with the cursor located on the REPL window.

Q. Is it possible to automatically change the REPL folder when I change
Vim folder?
A. Yes, but you need to define your own function, something like
```
def ChangeTerminalDir()
    for ii in term_list()
        if bufname(ii) == "JULIA"
           term_sendkeys(ii, 'cd("' .. getcwd() .. '")' .. "\n")
        else
           term_sendkeys(ii, "cd " .. getcwd() .. "\n")
        endif
    endfor
enddef

augroup DIRCHANGE
    au!
    autocmd DirChanged global ChangeTerminalDir()
augroup END
```
>*Note*
>It does not work the other way around, i.e. if you change folder from a
>*terminal* buffer the Vim current folder won't change.

Q. When I call |:ReplicaConsoleToggle| the console window won't close.
A. Replica commands work only if executed from a buffer with a supported
*filetype*. That is, if you have an IPYTHON console displayed in a window and
you call |:ReplicaConsoleToggle|  from a text filetype buffer, then nothing
will happen.
However, you can close the window where the console is running with standard
Vim commands such as <c-w>q, :close, :$close, etc.

## Contributing
Contributions are more than welcome!

## Help
`:h vim-replica.txt`
