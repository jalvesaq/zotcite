#!/usr/bin/env python3

"""
Pandoc filter to add references from Zotero database to the YAML header.
"""

import sys
import subprocess
import re
import json
from pathlib import Path
from zotero import ZoteroEntries

if __name__ == "__main__":
    cmd = ['pandoc', sys.argv[1], '-t', 'markdown']
    doc = subprocess.run(cmd, capture_output=True, text=True).stdout
    z = ZoteroEntries()
    while True:
        res = re.search(
            r"\[\]{#ZOTERO_ITEM CSL_CITATION\s(.*?),\\\"schema\\\":\\\"[\w:/\.-]*?\\\"}\s\w+}\(.*?\)", doc, re.DOTALL)
        if not res:
            break
        cit = res.group(1)
        cit += "}"
        cit = cit.replace("\\\"", "\"")
        cit = cit.replace("\\\\", "\\")
        try:
            cit = json.loads(cit)
        except Exception as e:
            with open("debug.txt", "w") as fh:
                fh.write(cit)
            raise (e)
        cit_new = "["
        for cit_item in cit["citationItems"]:
            cit_new += z.GetCitationById(cit_item["id"]) + ";"
        cit_new = cit_new[:-1] + "]"
        doc = doc[:res.start()] + cit_new + doc[res.end():]
    inf = Path(sys.argv[1])
    outf = inf.parent / (inf.stem+".md")
    with open(outf, "w") as fh:
        fh.write(doc)
