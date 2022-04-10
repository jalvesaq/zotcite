#!/usr/bin/env python3

"""
Pandoc filter to add references from Zotero database to the YAML header.
"""

import sys
import os
import subprocess
import io
import re
import json
from zotero import ZoteroEntries

if __name__ == "__main__":
    # Get all references from ~/Zotero/zotero.sqlite
    z = ZoteroEntries()

    # Get json from pandoc (stdin)
    i = sys.stdin.read()

    # To avoid duplicated references, delete the visible part of the citation key
    i = re.sub('"citationId":"([^"]+)#[^"]+"', '"citationId":"\\1"', i)

    j = json.load(io.StringIO(i))

    # Get all citations from the markdown document
    cites = re.findall('"citationId":"([^"]+)","citation', i)
    c = sorted(set(cites))

    # Get the references for the found citekeys formatted as the YAML and put
    # the string into the YAML header of a dummy markdown document.
    r = z.GetYamlRefs(c)
    if r != '':
        r = '---\n' + r + '...\n\ndummy text\n'

    # To see the dummy markdown document created by `zotref` with the
    # references in its YAML header, set the environment variable
    # `DEBUG_zotref` with any value.
    if os.getenv('DEBUG_zotref'):
        with open('/tmp/DEBUG_zotref', 'w') as f:
            f.write(r)

    if r != '':
        # Convert the doc into json
        r = r.encode('utf-8')
        p = subprocess.Popen(['pandoc', '-f', 'markdown', '-t', 'json'],
                             stdout=subprocess.PIPE, stdin=subprocess.PIPE)
        refi = p.communicate(r)[0]
        refj = json.load(io.StringIO(refi.decode()))

        # Add the references to the original metadata:
        j['meta']['references'] = refj['meta']['references']

        # Rename the bib file to avoid overwriting the original one:
        if 'bibliography' in j['meta']:
            j['meta']['bibliography']['c'][0]['c'] = '/tmp/zotcite_' + j['meta']['bibliography']['c'][0]['c']

    # Print the new json representation of the new document
    sys.stdout.write(json.dumps(j))
