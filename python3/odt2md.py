#!/usr/bin/env python3

"""
Pandoc filter to add references from Zotero database to the YAML header.
"""

import sys
import subprocess
import re
from zotero import ZoteroEntries

if __name__ == "__main__":
    p = subprocess.Popen(['pandoc', sys.argv[1], '-t', 'markdown'],
                         stdout=subprocess.PIPE)
    lines = p.communicate()[0].decode()
    lines = lines.replace('[]{#ZOTERO_ITEM ', '\x02')
    llist = lines.split('\x02')

    z = ZoteroEntries()

    for i in range(len(llist)):
        if llist[i].find('CSL_CITATION') == 0:
            zotid = re.sub('.*"id":([0-9]*),.*', '\\1', llist[i], flags=re.DOTALL)
            citation = z.GetCitationById(int(zotid))
            llist[i] = re.sub('CSL_CITATION .*json"} .[^}]*}',
                              '[' + citation + ']', llist[i])

    mdf = sys.argv[1].replace('.odt', '') + '.md'
    with open(mdf, 'w') as f:
        f.writelines(''.join(llist))
    print(mdf)
