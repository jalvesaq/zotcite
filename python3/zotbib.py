#!/usr/bin/env python3

"""
Application to extract citation keys from a Markdown document, get the
references from the Zotero database and save them in a bib file.
"""

import sys
import re
from zotero import ZoteroEntries

if __name__ == "__main__":

    if len(sys.argv) != 3:
        sys.stderr.write('Usage:\n\n  ' + sys.argv[0] + ' file_name.md file_name.bib\n')
        sys.exit(1)

    # Get all citation keys form argv[1]
    with open(sys.argv[1], "r") as f:
        lines = f.readlines()

    md = ' '.join(lines)
    keys = set(re.findall(r'[\W^\\]@([a-zA-Z0-9à-öø-ÿÀ-ÖØ-ß_:#-]+)', md))

    # Get all references from ~/Zotero/zotero.sqlite
    z = ZoteroEntries()
    r = z.GetBib(keys)

    # Save the bib file
    with open(sys.argv[2], 'w') as f:
        f.write(r)
