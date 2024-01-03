# Zotcite

_Zotcite_ is a Vim plugin that provides integration with Zotero. With
_zotcite_ you can:

  - Do omni completion of citation keys from Zotero database in
    Markdown, RMarkdown and Quarto documents.

    ![Omni completion](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_completion.gif "omni completion")

    ![Citation key highligting](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_conceal.gif "Citation key highlighting")

  - Quickly see on the status bar information on the reference under the cursor.

    ![Reference brief information](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_info.gif "Reference brief information")

    ![Complete reference information](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_more_info.gif "Complete reference information")

  - Use the `zotref.py` filter to pre-process the Markdown document before the
    citations are processed by `pandoc`, avoiding the need of `bib` files.

  - Open the PDF attachment of the reference associated with the citation key
    under the cursor.

  - Extract highlighted text and text notes from PDF attachments of
    references.

  - Extract Zotero notes from Zotero database.

  - Add all cited references to the YAML header of the Markdown document.

_Zotcite_ is being developed and tested on Linux and should work flawlessly on
other Unix systems, such as Mac OS X. It may require additional configuration
on Windows.


## Installation

Requirements:

  - Zotero >= 5

  - Python 3

  - Python 3 modules pynvim (see Neovim documentation on `provider-python` for
    details) and PyYAML.

  - Python modules PyQt5 and popplerqt5 (only if you are going to extract
    annotations from PDF documents). On Debian based Linux distributions, you
    can install them with the command:

    `sudo apt install python3-pyqt5 python3-poppler-qt5`

Depending on your system, you may have to install python modules in an virtual
environment and maybe also system-wide.

Zotcite can be installed as any Vim plugin. If using Neovim, you may also want
to install [cmp-zotcite](https://github.com/jalvesaq/cmp-zotcite).

The Python module `zotero` does not import the `vim` module. Hence, its code
could easily be adapted to other text editors such as Emacs.

## Usage

Please, read the plugin's
[documentation](https://raw.githubusercontent.com/jalvesaq/zotcite/master/doc/zotcite.txt)
for further instructions.

## Known bug

Zotcite syntax highlighting will not be enabled if the file type is `pandoc`.

## Acknowledgment

Zotcite's Python code was based on the
[citation.vim](https://github.com/rafaqz/citation.vim) project.
