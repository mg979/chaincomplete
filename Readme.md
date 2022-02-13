## chaincomplete.nvim

This is a completion plugin that leverages on built-in `ins-completion`, similar to [vim-mucomplete](https://github.com/lifepillar/vim-mucomplete).

Each buffer can have its own completion chain, that is made of several completion methods that are tried one after the other, until one produces some results. Chain methods can also be skipped with a mapping.

Autocompletion (completion as you type) is supported but it's not default.

-------------------------------------------------------------------------------

### Features

Supported completion methods:

- built-in completion methods (`:help ins-completion`)
- LSP completion

Optional features:

- autocompletion (as you type)
- function documentation popup (during completion)
- signature help (function parameters)
- custom methods, with handlers based on `complete()`

-------------------------------------------------------------------------------

### Quick start

Unless you have already mapped <kbd>Tab</kbd> and <kbd>C-j</kbd> in insert mode, you don't need any special setup.

Note that autocompletion is disabled by default. To enable it:

    :AutoComplete on

or in your vimrc:

    vim.g.chaincomplete = { autocomplete = true }

while this will enable it for triggers only:

    :AutoComplete triggers

or in your vimrc:

    vim.g.chaincomplete = { autocomplete = 'triggers' }

If you want to integrate it with some snippets plugin, there are plugs available, that you can use with `nvim_feedkeys()`.

For the rest of the documentation, `:help chaincomplete`

-------------------------------------------------------------------------------

### Credits

Bram Moolenar for Vim  
Lifepillar for [vim-mucomplete](https://github.com/lifepillar/vim-mucomplete)  
Evgeni Chasnovski for [mini.vim](https://github.com/echasnovski/mini.nvim)
