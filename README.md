# **REPL**ica.vim
REPL for Scientific applications.

<p align="center">
<img src="/OutlineDemo.gif" width="60%" height="60%">
</p>

## Introduction
Replica allows REPL programs such as Python or Julia, inside Vim in a seamless
way.

Replica supports the following key features:

1. Sending lines, files and code-cells to a REPL,
2. Code-cells highlighting.

Each REPL is a `jupyter console` initiated with a specific kernel running in a
*terminal* buffer. <br>
For each *filetype* Replica provides you with one
available REPL to send text in.

I wrote vim-replica because I never managed to make
[vim-slime](https://github.com/jpalardy/vim-slime) to work
satisfactory under Windows and
[vim-REPL](https://github.com/sillybun/vim-repl) crashes too often when using
the toggle function. Also because the mentioned plugins are way too general
and I needed something focused on Scientific applications.

## Requirements
Replica is written in *Vim9script*, and you need at least Vim 9.0.<br>
Furthermore, you need `jupyter console` and the *kernels* associated to the
language you would like to use.

You can google to discover the available jupyter kernels out there whereas you
can run `jupyter kernelspec list` from the command line of your terminal to
see the list of kernels installed on your machine.

Search for `jupyter console` docs on the Internet for more information.

## Usage
#### Commands
`:ReplicaConsoleToggle`     - un-hide and hide the REPL.

`:ReplicaConsoleRestart`    - restart the REPL.

`:ReplicaConsoleShutoff`    - wipeout the buffer associated to the REPL.

`:[range]ReplSendLines`     - send the lines in *[range]* to the REPL.

`:ReplicaSendCell`          - send the current code-cell.

`:ReplicaSendFile [{file}]` - send {file} to the REPL.

`:ReplicaRemoveCells`       - remove all the cells from the current buffer.


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

> **Warning**
>
> Both the above commands and mappings work only if they are run from a buffer
> whose *filetype* is supported.

## Basic Configuration
```
# Default values
g:replica_enable_highlight = true
g:replica_console_position = "L"
g:replica_console_height = &lines
g:replica_console_width = floor(&columns/2)
g:replica_kernels = {"python": "python3",
                   \ "julia": "julia-1.8"}
g:replica_cells_delimiters = { "python": "# %%",
                             \ "julia": "# %%"}
```

## Adding new languages
At the moment vim-replica only support *python* and *julia*.<br>
However, this plugin is nicely extendable and adding new languages is easy.

Say that a new language is associated to a certain *filetype*.<br>
Then, you can add it to replica in two steps:

1. Add a new key-value pair to the `g:replica_kernels`, `g:replica_names`,
  `g:replica_cells_delimiters` and `g:replica_run_commands` dictionaries.
2. Duplicate any existing vim-replica/ftplugin/*.vim file and rename it
   according to the newly included *filetype*.

Done!

> **Note**
>
> You may use the global `ftplugin` folder but it has not been tested yet.

## Troubleshooting

*Q.* My Vim became slow!

*A.* You can try to set `g:replica_alt_highlight` = true in your *vimrc*.<br>
Or, if still slow, you can try to disable the cells
highlighting by setting `g:replica_enable_highlight` to false.


*Q.* Is it possible to copy from the REPL to a buffer?

*A.* Yes! If you `<c-w>N` in your REPL, then it becomes an ordinary buffer.<br>
There you can yank everything you want.
To re-enable the REPL press i with the cursor located on the REPL window.


*Q.* Is it possible to automatically change the REPL folder when I change
Vim folder?

*A.* Yes, but you need to define your own function, something like
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
>**Note***
>
>The above function is an example and it has its own limitations.
>For example, it does not work the other way around, i.e. if you change folder
>from a
>*terminal* buffer the Vim current folder won't change.

*Q.* When I call `:ReplicaConsoleToggle` the console window won't close.

*A.* Replica commands work only if executed from a buffer with a supported
*filetype*. That is, if you have an IPYTHON console displayed in a window and
you call `:ReplicaConsoleToggle`  from a text filetype buffer, then nothing
will happen.
You can close the window where the console is running with standard
Vim commands such as `<c-w>q`, `:close`, `:$close`, etc.

## Contributing
Contributions are more than welcome!

## Help
`:h vim-replica.txt`

## License
Vim license.
