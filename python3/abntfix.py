#!/usr/bin/env python3

"""
Pandoc filter to fix ABNT citations.
"""

import sys
import io
import json

def TitleCase(x):
    if x in [ 'a', 'an', 'and', 'in', 'the', 'de', 'do', 'da', 'dos', 'das',
             'com', 'na', 'no', 'nas', 'nos', 'e', 'um', 'uma']:
        return x
    return x.title()

if __name__ == "__main__":
    sys.stderr.write('Running abntfix...\n')
    sys.stderr.flush()

    # Get json from pandoc (stdin)
    i = sys.stdin.read()
    j = json.load(io.StringIO(i))
    for e, ve in enumerate(j['blocks']):
        if ve['t'] == 'Para':
            for p, vp in enumerate(j['blocks'][e]['c']):
                if vp['t'] == 'Cite':
                    if j['blocks'][e]['c'][p]['c'][0][0]['citationMode']['t'] == 'AuthorInText':
                        ultimo = 1000
                        for s, vs in enumerate(j['blocks'][e]['c'][p]['c'][1]):
                            if vs['t'] == 'Str':
                                if j['blocks'][e]['c'][p]['c'][1][s]['c'] == 'and':
                                    j['blocks'][e]['c'][p]['c'][1][s]['c'] = 'e'
                                else:
                                    j['blocks'][e]['c'][p]['c'][1][s]['c'] = TitleCase(j['blocks'][e]['c'][p]['c'][1][s]['c'])
                                    if j['blocks'][e]['c'][p]['c'][1][s]['c'].find(';') > -1:
                                        ultimo = s
                                        j['blocks'][e]['c'][p]['c'][1][s]['c'] = j['blocks'][e]['c'][p]['c'][1][s]['c'].replace(";", ",")
                        if ultimo < 1000:
                            j['blocks'][e]['c'][p]['c'][1][ultimo]['c'] = j['blocks'][e]['c'][p]['c'][1][ultimo]['c'].replace(",", " e")

    # Print the json representation of the new document
    sys.stdout.write(json.dumps(j))
