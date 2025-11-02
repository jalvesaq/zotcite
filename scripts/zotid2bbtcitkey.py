#!/usr/bin/env python3

# Convert Zotero IDs into Better BibTeX (BBT) citation keys in a Markdown document
# These are the citation keys exported by Zotero File->Export Library with the "Better BibLaTeX" format
# and can be used in Quarto by setting the `bibliography:` YAML parameter to the exported .bib file

import requests
import sys
import json
import re


def zotid2citkey(zotid):
    # Convert a Zotero ID into a Better BibTeX (BBT) citation key
    #
    # See
    # https://github.com/retorquere/zotero-better-bibtex/discussions/3034#discussioncomment-11029462
    url = "http://localhost:23119/better-bibtex/json-rpc"
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    data = {
        "jsonrpc": "2.0",
        "method": "item.citationkey",
        "params": {"item_keys": [zotid]}
    }
    res = requests.post(url=url, headers=headers, data=json.dumps(data))
    ress = list(res.json()["result"].items())
    citkey = ress[0][1]
    return (citkey)


fh = open(sys.argv[1], "r")
inf = fh.read()
fh.close()

ms = re.finditer(r"@\w+#[\w-]+(?=\]|;)", inf)

last_m = None
for m in ms:
    if last_m is None:
        outs = inf[0:m.start()]
    else:
        outs += inf[last_m.end():m.start()]
    last_m = m
    zotid = m.group(0)
    if "#" in zotid:
        zotid = zotid.split("#")[0]
    zotid = re.sub("^@", "", zotid)
    bbtid = zotid2citkey(zotid)
    outs += "@" + bbtid

# Insert last part
outs += inf[last_m.end():]

with open(sys.argv[2], "w") as fh:
    fh.write(outs)
