# Zotcite

> [!Note]
> Users of Vim and Neovim < 0.10.4 have to switch to the "vim" branch.

> [!Note]
> Users of Neovim < 0.12 have to switch to the "no_pynvim" branch.

> [!Note]
> Zotcite now updates a bib file and inserts the "Author-Year" part of the
> citation key as virtual text. Consequently, it no longer requires the
> `zotref` filter. If you prefer the old system, please, switch to the
> "no_pynvim" branch.

_Zotcite_ is a Neovim plugin that provides integration with Zotero for
Markdown, Quarto, Rmd, vimwiki, Typst, LaTeX, and Rnoweb file types. With
_zotcite_ you can:

  - Do auto-completion of citation keys from Zotero database in
    Markdown, RMarkdown, Quarto, and Typst (requires `cmp-zotcite` if Neovim <
    0.12).

    ![Auto-completion](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_completion.gif "auto-completion")

    ![Citation key highlighting](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_conceal.gif "Citation key highlighting")

  - Quickly see on the status bar information on the reference under the cursor.

    ![Reference brief information](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_info.gif "Reference brief information")

    ![Complete reference information](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_more_info.gif "Complete reference information")

  - Use the `zotref.py` filter to pre-process the Markdown document before the
    citations are processed by `pandoc`, avoiding the need of `bib` files.

  - Open the PDF attachment of the reference associated with the citation key
    under the cursor.

  - Extract highlighted text and text notes from PDF attachments of
    references.

  - Extract Zotero notes and annotations from Zotero database.

  - Add all cited references to the YAML header of the Markdown document.

_Zotcite_ is being developed and tested on Linux and should work flawlessly on
other Unix systems, such as Mac OS X. It may require additional configuration
on Windows.


## Installation

**Dependencies**

- Required:

  - Zotero >= 5

  - [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) as
    well as tree-sitter parsers for `markdown`, `markdown_inline`, and `yaml`.
    If editing LaTeX or Rnoweb files, you will also need their parsers.

- Optional:

  - [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) as an
    alternative way of inserting citation keys.

  - Python 3 is required if are going to convert an OpenDocument text (`odt`)
    to markdown or extract annotations inserted in a PDF document by a PDF
    viewer other than Zotero. Please, see Zotcite documentation for details).

Zotcite can be installed as any Neovim plugin. Below is an example of how to
install `zotcite` with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
    {
        "jalvesaq/zotcite",
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-telescope/telescope.nvim",
        },
        config = function ()
            require("zotcite").setup({
                -- your options here (see doc/zotcite.txt)
            })
        end
    },
```

> [!Note]
> You don't need to lazy load zotcite because it is a filetype plugin which
> means that it already lazy loads its modules, which will be enabled only for
> the supported file types.

## Usage

Please, read the plugin's
[documentation](https://raw.githubusercontent.com/jalvesaq/zotcite/master/doc/zotcite.txt)
for further instructions.

## See also:

Zotcite's original Python code was based on the
[citation.vim](https://github.com/rafaqz/citation.vim) project.

Similar project, but depending on BetterBibtex:

[telescope-zotero.nvim](https://github.com/jmbuhr/telescope-zotero.nvim)
