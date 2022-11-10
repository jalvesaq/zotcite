#!/usr/bin/env python3

"""
Pandoc filter to add references from Zotero database to the YAML header.
"""

import sys
import os
import subprocess
import io
import tempfile
import re
import json
from zotero import ZoteroEntries

cites =[]

def WalkClean(x):
    if isinstance(x, dict) and 't' in x.keys() and x['t'] == 'Cite':
        for a in x['c'][0]:
            a['citationId'] = re.sub('#.*', '', a['citationId'])
            cites.append(a['citationId'])
    else:
        if isinstance(x, dict) and 'c' in x.keys() and isinstance(x['c'], list):
            for y in x['c']:
                WalkClean(y)
        else:
            if isinstance(x, list):
                for y in x:
                    WalkClean(y)

if __name__ == "__main__":
    # Get all references from ~/Zotero/zotero.sqlite
    z = ZoteroEntries()

    # Get json from pandoc (stdin)
    i = sys.stdin.read()

    j = json.load(io.StringIO(i))

    # To avoid duplicated references, delete the visible part of the citation key
    # and get all citations from the markdown document
    WalkClean(j['blocks'])

    c = sorted(set(cites))

    if 'bibliography' in j['meta']:
        b = j['meta']['bibliography']['c']
        zbib = None
        if isinstance(b, list):
            for n in b:
                nstr = ''
                if isinstance(n['c'], list):
                    nstr = n['c'][0]['c']
                else:
                    if isinstance(n['c'], str):
                        nstr = n['c']
                if nstr.find('zotcite.bib') == (len(nstr) - 11):
                    zbib = nstr
                    break
            if zbib is None:
                zbib = tempfile.gettempdir() + '/' + os.getlogin() + '_zotcite.bib'
                zitem = {'t': 'MetaInlines', 'c': [{'t': 'Str', 'c': zbib}]}
                if j['meta']['bibliography']['t'] == 'MetaList':
                    j['meta']['bibliography']['c'].append(zitem)
                else:
                    if j['meta']['bibliography']['t'] == 'MetaInlines':
                        j['meta']['bibliography'] = {'t': 'MetaList', 'c': [j['meta']['bibliography'], zitem]}

        r = z.GetBib(c)

        # Save the bib file
        if os.getenv('QUARTO_FILTER_PARAMS'):
            if os.path.exists(zbib):
                sys.stderr.write('zotref (zotcite): overwriting "' + str(zbib) + '"\n')
            else:
                sys.stderr.write('zotref (zotcite): writing "' + str(zbib) + '"\n')
            sys.stderr.flush()
        with open(zbib, 'w') as f:
            f.write(r)
    else:
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

    # Print the json representation of the new document
    sys.stdout.write(json.dumps(j))
