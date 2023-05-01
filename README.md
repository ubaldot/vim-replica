# **REPL**ica.vim

<p align="center">
<img src="/ReplicaDemo.gif" width="75%" height="75%">
Enjoy Jupyter with Vim.
</p>

<!-- <p align="center" style="font-size:24;"> -->
<!-- * Enjoy Jupyter through Vim! * -->
<!-- </p> -->

## Introduction
Replica allows REPL shells such as IPython or Julia inside Vim in a seamless
way.

It supports the following key features:

1. Send lines, files and code-cells to a REPL,
2. Highlight code-cells.


I wrote vim-replica because I always had problems with
[vim-slime](https://github.com/jpalardy/vim-slime) under Windows and
[vim-REPL](https://github.com/sillybun/vim-repl) crashes too often when using
the toggle function and I discovered
[jupyter-vim](https://github.com/jupyter-vim/jupyter-vim) too late.

If you like this plugin you may also want to take a look at
[vim-outline](https://github.com/ubaldot/vim-outline).

## Requirements
Replica is entirely written in *Vim9script* so you need at least
Vim 9.0.<br>
If you are using Windows be sure that Python and Vim are both 32- or
64-bit.<br>


Each REPL is a [jupyter console](https://github.com/jupyter/jupyter_console)
initiated with a specific
[kernel](https://github.com/jupyter/jupyter/wiki/Jupyter-kernels) running in a
*terminal* buffer and for each *filetype* Replica provides you with one
available REPL to send text in.
You need [jupyter console](https://github.com/jupyter/jupyter_console)
and the [kernels](https://github.com/jupyter/jupyter/wiki/Jupyter-kernels)
of the language you would like to use to enjoy Replica.

## Usage
#### Commands
`:ReplicaConsoleToggle`     - un-hide and hide the REPL.

`:ReplicaConsoleRestart`    - restart the REPL.

`:ReplicaConsoleShutoff`    - wipeout the buffer associated to the REPL.

`:[range]ReplicaSendLines`  - send the lines in *[range]* to the REPL.

`:ReplicaSendCell`          - send the current code-cell.

`:ReplicaSendFile [{file}]` - send {file} to the REPL. If no file is given,
send the content of the current buffer.

`:ReplicaRemoveCells`       - remove all the cells from the current buffer.


#### Mappings
```
# Default mappings
nmap <F2> <Plug>ReplicaConsoleToggle<cr>

nmap <F9> <Plug>ReplicaSendLines<cr>
xmap <F9> <Plug>ReplicaSendLines<cr>

nmap <F5> <Plug>ReplicaSendFile<cr>

nmap <c-enter> <Plug>ReplicaSendCell<cr>j
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
At the moment Replica support *python* and *julia* but adding new
languages should not be too difficult.<br>

Say that you want to add `foo` language to Replica.
You proceed in two steps:

1. Add a new key-value pair to the `g:replica_kernels`, `g:replica_names`,
  `g:replica_cells_delimiters` and `g:replica_run_commands` dictionaries.
   Take a look at `:h replica.txt` to understand how to set them.
2. Duplicate any existing file in `vim-replica/ftplugin/` file and rename it
   as `foo.vim`. Note that `foo` must be a recognized vim *filetype*.

Done!<br>
Your new language is now added to vim-replica!
If you add a new language consider to issue a PR.

> **Note**
>
> You could also use the global `ftplugin` folder instead of the plugin
> `vim-replica/ftplugin` folder but that has not been tested yet.

## Troubleshooting

*Q. IPython won't start.*

A. Be sure that in the current virtual environment:

1. `jupyter console` is installed,
2. some `ipython` jupyter kernel (e.g. `pyhon3`) is installed,
3. vim is launched from this virtual environment.

*Q. When I open the REPL the layout is horrible!*

A. Set a desired value of `g:replica_console_height` and
`g:replica_console_width` in your `vimrc`.<br>
The units are number of lines and number of columns, respectively. <br>

*Q. My Vim became slow!*

A. You can try to set `g:replica_alt_highlight = true` in your *vimrc*.<br>
Or, if still slow, you can try to disable the cells
highlighting by setting `g:replica_enable_highlight` to `false`.


*Q. When I call `:ReplicaConsoleToggle` the console window won't close.*

A. Replica commands work only if executed from a buffer with a supported
*filetype*. <br>
That is, if you have an *IPYTHON* console displayed in a window and
you call `:ReplicaConsoleToggle`  from a `text` *filetype* buffer, then
nothing
will happen.
You can close the window where the console is running with standard
Vim commands such as `<c-w>q`, `:close`, `:$close`, etc.

*Q. Is it possible to copy from the REPL to a buffer?*

A. Yes! If you `<c-w>N` in your REPL, then it becomes an ordinary buffer.<br>
There you can yank everything you want.<br>
To re-enable the REPL press `i` with the cursor located on the REPL window.


*Q. Is it possible to automatically change the REPL folder when I change
Vim folder?*

A. Yes, but you need to define your own function, something like the
following:
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
>**Note**
>
>The above function is an example and it has its own limitations.
>For example, it does not work the other way around, i.e. if you change folder
>from a
>*terminal* buffer then the Vim current folder won't change.


## Contributing
Contributions are more than welcome!<br>
In the source code there are TODO items.
Feel free to address any of them or propose your own change.

## Help
`:h replica.txt`

## License
Vim license.
