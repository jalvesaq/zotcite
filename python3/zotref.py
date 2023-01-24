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

def ReadBib(fnm):
    bib = {}
    key = None
    with open(fnm) as f:
        for line in f:
            if line[0] == '@':
                key = re.sub('^@.*{', '', re.sub(',\\s*$', '', line))
                bib[key] = []
            if key:
                bib[key].append(line)
    return bib

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

    if 'abstract' in j['meta']:
        WalkClean(j['meta']['abstract'])

    c = sorted(set(cites))

    if 'bibliography' in j['meta']:
        b = j['meta']['bibliography']['c']
        zbib = ""
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
            if zbib == "":
                zbib = tempfile.gettempdir() + '/' + os.getlogin() + '-zotcite.bib'
                zitem = {'t': 'MetaInlines', 'c': [{'t': 'Str', 'c': zbib}]}
                if j['meta']['bibliography']['t'] == 'MetaList':
                    j['meta']['bibliography']['c'].append(zitem)
                else:
                    if j['meta']['bibliography']['t'] == 'MetaInlines':
                        j['meta']['bibliography'] = {'t': 'MetaList', 'c': [j['meta']['bibliography'], zitem]}

        # Get fresh references
        r = z.GetBib(c)

        # Save the bib file
        if os.path.exists(zbib):
            sys.stderr.write('zotref (zotcite): updating "' + str(zbib) + '"\n')
            # Read old references
            o = ReadBib(zbib)
            # Replace old references with new ones
            for key in r.keys():
                o[key] = r[key]
        else:
            sys.stderr.write('zotref (zotcite): writing "' + str(zbib) + '"\n')
            o = r
        sys.stderr.flush()

        with open(zbib, 'w') as f:
            for k in o.keys():
                f.write("\n" + "".join(o[k]))

        if os.name == "nt":
            enc = os.getenv('Zotero_encoding')
            if enc is None:
                enc = "latin1"
            with open(zbib, encoding=enc) as f:
                bib = f.read()
            with open(zbib, 'w', encoding='utf8') as f:
                f.write(bib)

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
