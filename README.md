# **REPL**ica.vim

<p align="center">
<!-- asciinema demo goes here -->
</p>

<p align="center" style="font-size:38;">
* The ultimate REPL! *
</p>

## Introduction

Replica integrates with the following REPL programs:

- IPython
- Julia
- R
- sh
- zsh
- PowerShell

Additional REPL can be easily included. See `:h ReplicaContributing`.

Replica supports the following key features:

1. Send lines, files and code-cells to a REPL,
2. Highlight code-cells,
3. Variable inspector (Python, Julia, R).

I wrote vim-replica because I always had problems with [vim-slime][1] under
Windows and [vim-REPL][2] crashes too often when using the toggle function.

If you like this plugin you may also want to take a look at [vim-outline][3].

## Requirements

Replica is entirely written in Vim9script, hence you need at least Vim 9.0
compiled with `python3` support.

## Usage

#### Commands

```vim
`:ReplicaConsoleToggle`         # Un-hide and hide the REPL
`:ReplicaConsoleRestart`        # Restart the REPL
`:ReplicaConsoleShutoff`        # Wipeout the buffer associated to the REPL
`:[range]ReplicaSendLines`      # Send the lines in `[range]` to the REPL
`:ReplicaSendCell`              # Send the current code cell
`:ReplicaSendFile [{file}]`     # Send `{file}` to the REPL. If no file is given, it send the current buffer
`:ReplicaRemoveCells`           # Remove all the cells from the current buffer
`:ReplicaInspect [{variable}]`  # Display `{variable}`. If no argument is given, display all variables in the current session
```

#### Mappings

By setting `g:replica_config.use_default_mapping = true` you will get the
following mappings:

```vim
# Default mappings
nmap <F2> <Plug>ReplicaConsoleToggle<cr>
nmap <F9> <Plug>ReplicaSendLines<cr>
xmap <F9> <Plug>ReplicaSendLines<cr>
nmap <F5> <Plug>ReplicaSendFile<cr>
nmap <c-enter> <Plug>ReplicaSendCell<cr>j
```

##### Configuration

```vim
# Example
g:replica_config = {}
g:replica_config['console_position'] = "L"
g:replica_config['display_range'] = true
g:replica_config['enable_highlight'] = true
g:replica_config['alt_highlight'] = false
g:replica_config['use_default_mapping'] = false
g:replica_config['display_variables'] = 'tab'
g:replica_config['repl_options'] = {
    python: "",
    julia: "",
    r: "",
    sh: "",
    zsh: "",
    ps1: ""}
```

## Adding new languages

At the moment Replica supports _python_, _julia_, _R_, _sh_, _zsh_ and _ps1_ but adding new
languages should not be too difficult.

Say that you want to add `foo` language to Replica. You proceed in two steps:

1. Edit `plugin/replica.vim` and add a new key-value pair to the internal
   dictionaries.
   Take a look at `:h replica.txt` for details on what each entry should contain.
2. If the new REPL requires extra start-up options, add a corresponding entry
   to `g:replica_config.repl_options` in your `vimrc`.

Done!

Your new language is now added to vim-replica! If you add a new
language consider to issue a PR.

## Troubleshooting

#### Q: The REPL does not even start!

A: Ok, let's start with some basic checks:

1. Make sure the REPL executable is in your `$PATH` (e.g. `ipython`, `julia`,
   `Rscript`, `bash`, `zsh`, `pwsh`).
2. If you are using Python, make sure the virtual environment is active and
   `ipython` is installed in it, then launch Vim from that environment.
3. Run `:echo has('terminal')` — the answer must be `1`.

#### Q: When I open the REPL the layout is horrible!

A: Set a desired value of `g:replica_config.console_height` and
`g:replica_config.console_width` in your `vimrc`.

The units are number of lines and number of columns, respectively.

#### Q. Vim slow down a lot with this st\*pid plugin!

A: You can try to set `g:replica_config.alt_highlight = true` in your _vimrc_.

Or, if still slow, you can try to disable the cells highlighting by setting
`g:replica_config.enable_highlight` to `false`.

#### Q. I am using matplotlib and the figures are not interactive.

A: This is more a matplotlib setting than a replica problem. :)

You should change the matplotlib backend. For example, you could use the magic
`%matplotlib qt` to use the `qt` backend. See [matplotlib][4] docs for more info.

#### Q. The variable explorer is too small for my 800x800 matrix.

You can switch how you want to explore your variables through
`g:replica_config.display_variables`. Possible choices are `split`, `vsplit`,
`tab` and `popup`.


#### Q. When I call `:ReplicaConsoleToggle` the console window won't close.

A: Replica commands work if executed from a buffer with a supported
_filetype_.

That is, if you have an _IPYTHON_ console displayed in a
window and you call `:ReplicaConsoleToggle` from a `text` _filetype_ buffer,
then nothing will happen.

This because if you have a Python and a Julia
console open and you are editing a .txt file, then which console should close?
Python? Julia? Both?

At the moment, you can close the window where the console
is running with standard Vim commands such as `<c-w>q`, `:close`, `:$close`,
etc. Such a behavior may change if there is a sufficiently large amount of
users who wants that. :)

#### Q. Is it possible to copy from the REPL to a buffer?

A: Yes! If you `<c-w>N` in your REPL, then it becomes an ordinary buffer.

There you can yank everything you want.

To re-enable the REPL press `i` with the cursor located on the REPL window.

#### Q. Is it possible to automatically change the REPL folder when I change
#### Vim folder?

A: Yes, but you need to define your own function, something like the
following:

```
def ChangeTerminalDir()
    for ii in term_list()
        if bufname(ii) == "JULIA"
           term_sendkeys(ii, $'cd {getcwd()}\n")
        else
           term_sendkeys(ii, $'cd {getcwd()}\n')
        endif
    endfor
enddef

augroup DIRCHANGE
    au!
    autocmd DirChanged global ChangeTerminalDir()
augroup END
```

> **Note**
>
> The above function is an example and it has its own limitations. For
> example, it does not work the other way around, i.e. if you change folder
> from a _terminal_ buffer then the Vim current folder won't change.

## Help

This README is a good start to get some insights on Replica, but you can find
more info in `:h replica.txt`.

## License

BSD3-Clause.

<!-- DO NOT REMOVE vim-markdown-extras references DO NOT REMOVE-->
[1]: https://github.com/jpalardy/vim-slime
[2]: https://github.com/sillybun/vim-repl
[4]: https://matplotlib.org/stable/index.html
[3]: https://github.com/ubaldot/vim-outline
