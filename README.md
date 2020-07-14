# misdreavus-mru

This is a small plugin to add a most-recently-used buffer list to vim. It tracks which buffers have
been loaded most recently in a given window and allows you to recall and "rotate" through them.

## how to install

Point your preferred plugin manager to `'QuietMisdreavus/misdreavus-mru'` or clone the repo into
your `pack/` directory, or whatever you do to add vim plugins to your config.

## how to use

This plugin tracks when you enter/leave buffers, and keeps a list per-window of which buffers have
been used. To view the MRU list for the current window, use the `:Mru` command:

```
:Mru

%17:     pack/misdreavus/start/mru/README.md
#1:      pack/misdreavus/start/mru/plugin/mru.vim
 16:     vimrc
 4:      plugin/tabline.vim
 15:     plugin/statusline.vim
 9:      README.md
```

The current buffer is on the top, noted with a `%`. The "alternate" buffer (accessible with
`Ctrl-6`/`Ctrl-^`) is right below that, noted with a `#`. The list then extends below that, farther
back in time.

The `:Mru` command also takes a count, either before the command name or as the first argument, to
limit the number of buffers displayed:

```
:Mru 3

%17:     pack/misdreavus/start/mru/README.md
#1:      pack/misdreavus/start/mru/plugin/mru.vim
 16:     vimrc
```

`misdreavus-mru` also has functionality to "rotate" the most recent N buffers by giving a command to
load the Nth buffer in the list. By default, N is 3, but this can be changed by setting the
`g:misdreavus_mru_rotate_count` variable. Setting it to 0 disables this functionality.

To rotate the MRU list, the function `RotateMru()` is available. A mapping is available to call this
as `<Plug>RotateMru`. I recommend mapping `Ctrl-7` to this, to mirror the "alternate buffer"
switching behavior available by default on `Ctrl-6`:

```vim
" map Ctrl-7 to rotate buffers in misdreavus-mru
" (mapping needs to be recursive (i.e. not using :nnoremap) because of how it's defined in the
" plugin)
nmap <C-_> <Plug>RotateMru
```

## integrating it with displays

[`ghostline`] is integrated with this plugin, to show the top N buffers to the far-left of the
tabline. It does this by accessing the `g:misdreavus_mru` dict, which tracks the MRU lists using the
window IDs as keys. The values in the dict are lists of buffer numbers. For example, this is how the
list might look at one given moment:

```
{
    '1000': [17, 1, 16, 4, 15, 9],
    '1001': [1],
    '1002': [3]
}
```

[`ghostline`]: https://github.com/QuietMisdreavus/ghostline

By checking `g:misdreavus_mru[win_getid()]`, you can access the list and use the buffer numbers to
populate a display list.

## enabling/disabling

The MRU tracking is enabled by default when the plugin is loaded. To disable this behavior, set the
`g:misdreavus_mru_no_auto_enable` variable to any value prior to loading the plugin.

To enable or disable the plugin after it's loaded, the commands `:EnableMru` and `:DisableMru` are
available.

## license

This code is available under the Mozilla Public License, version 2.0. For more information, see the
`LICENSE` file.
