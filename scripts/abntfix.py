#!/usr/bin/env python3

"""
Pandoc filter to fix ABNT citations.
"""

import sys
import io
import json

def TitleCase(x):
    if x in [ 'et', 'al.', 'a', 'an', 'and', 'in', 'the', 'de', 'do', 'da',
             'dos', 'das', 'com', 'na', 'no', 'nas', 'nos', 'e', 'um', 'uma']:
        return x
    return x.title()

def WalkFix(x):
    if isinstance(x, dict) and 't' in x.keys() and  x['t'] == 'Cite' and x['c'][0][0]['citationMode']['t'] == 'AuthorInText':
        ultimo = 1000
        for s, vs in enumerate(x['c'][1]):
            if vs['t'] == 'Str':
                vs['c'] = TitleCase(vs['c'])
                if vs['c'].find(';') > -1:
                    ultimo = s
                    vs['c'] = vs['c'].replace(";", ",")
        if ultimo < 1000:
            x['c'][1][ultimo]['c'] = x['c'][1][ultimo]['c'].replace(",", " e")
    else:
        if isinstance(x, dict) and 'c' in x.keys() and isinstance(x['c'], list):
            for y in x['c']:
                WalkFix(y)
        else:
            if isinstance(x, list):
                for y in x:
                    WalkFix(y)

if __name__ == "__main__":
    sys.stderr.write('Running abntfix...\n')
    sys.stderr.flush()

    # Get json from pandoc (stdin)
    i = sys.stdin.read()
    j = json.load(io.StringIO(i))

    WalkFix(j['blocks'])

    # Print the json representation of the new document
    sys.stdout.write(json.dumps(j))
