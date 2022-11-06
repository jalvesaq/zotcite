#!/usr/bin/env python3

"""
Pandoc filter to fix APA citations.

There is a lua filter for this in the R package rmdfiltr, but the package
seems to be abandoned and its filter no longer works.
"""

import sys
import io
import json
import re

def TranslateAmpersand(lang):
    lang = re.sub('_.*', '', lang)
    translation = {'en': 'and',
                   'de': 'und',
                   'es': 'y',
                   'fr': 'et',
                   'nl': 'en',
                   'pt': 'e'}
    if lang in translation.keys():
        return translation[lang]
    else:
        return 'and'

if __name__ == "__main__":
    sys.stderr.write('Running apafix...\n')
    sys.stderr.flush()

    # Get json from pandoc (stdin)
    i = sys.stdin.read()
    j = json.load(io.StringIO(i))

    # Translate "&" according to specific language, as in
    # https://github.com/crsh/rmdfiltr/blob/master/inst/replace_ampersands.lua
    if 'lang' in j['meta'].keys():
        as_str = TranslateAmpersand(j['meta']['lang']['c'][0]['c'])
    else:
        as_str = 'and'

    for e, ve in enumerate(j['blocks']):
        if ve['t'] == 'Para':
            for p, vp in enumerate(j['blocks'][e]['c']):
                if vp['t'] == 'Cite':
                    if j['blocks'][e]['c'][p]['c'][0][0]['citationMode']['t'] == 'AuthorInText':
                        ultimo = 1000
                        for s, vs in enumerate(j['blocks'][e]['c'][p]['c'][1]):
                            if vs['t'] == 'Str' and j['blocks'][e]['c'][p]['c'][1][s]['c'] == '&':
                                j['blocks'][e]['c'][p]['c'][1][s]['c'] = as_str

    # Print the json representation of the new document
    sys.stdout.write(json.dumps(j))
