# Zotcite

_Zotcite_ is a Vim plugin that provides integration with Zotero. With
_zotcite_ you can:

  - Do omni completion of citation keys from Zotero database in both
    Markdown and RMarkdown documents.

    ![Omni completion](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_completion.gif "omni completion")

    ![Citation key highligting](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_conceal.gif "Citation key highlighting")

  - Quickly see on the status bar information on the reference under the cursor.

    ![Reference brief information](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_info.gif "Reference brief information")

    ![Complete reference information](https://raw.githubusercontent.com/jalvesaq/zotcite/master/zotcite_more_info.gif "Complete reference information")

  - Use the `zotref` filter to pre-process the Markdown document before it is
    passed to `pandoc-citeproc`, avoiding the need of `bib` files. The
    `zotref` filter receives the Markdown document from its standard input,
    extracts all citation keys from the document, gets all corresponding
    references from the Zotero database, inserts all references in the YAML
    header of the document and, finally, pass the enhanced document to
    `pandoc-citeproc`.

  - Open the PDF attachment of the reference associated with the citation key
    under cursor.

  - Extract highlighted text and text notes from PDF attachments of
    references.

  - Extract Zotero notes from Zotero database.

  - Add all cited references to the YAML header of the Markdown document.

_Zotcite_ is being developed and tested on Linux and should work flawlessly on
other Unix systems, such as Mac OS X. It may require additional configuration
on Windows.


## Installation

Requirements:

  - Zotero 5

  - Python 3

  - Python modules PyQt5 and popplerqt5 (only if you are going to extract
    annotations from PDF documents). On Debian based Linux distributions, you
    can install them with the command:

    `sudo apt install python3-pyqt5 python3-poppler-qt5`

Zotcite can be installed as any Vim plugin. It is recommended the use of a
plugin manager, such as [Vim-Plug](https://github.com/junegunn/vim-plug).

The `zotero` module does not import the `vim` module. Hence, its code could
easily be adapted to other text editors such as Emacs or Gedit.

## Usage

Please, read the plugin's
[documentation](https://raw.githubusercontent.com/jalvesaq/zotcite/master/doc/zotcite.txt)
for further instructions.

## Known bug

Zotcite syntax highlighting will not be enabled if the file type is `pandoc`.

## Acknowledgment

Zotcite code is based on the
[citation.vim](https://github.com/rafaqz/citation.vim) project which provides
[Unite](https://github.com/Shougo/unite.vim) sources for insertion of Zotero
and bibtex citation keys and has many other features.
