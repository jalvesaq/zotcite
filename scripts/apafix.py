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

as_str = "and"

def WalkFix(x):
    if isinstance(x, dict) and 't' in x.keys() and x['t'] == 'Cite' and x['c'][0][0]['citationMode']['t'] == 'AuthorInText':
        for vs in x['c'][1]:
            if vs['t'] == 'Str' and vs['c'] == '&':
                vs['c'] = as_str
    else:
        if isinstance(x, dict) and 'c' in x.keys() and isinstance(x['c'], list):
            for y in x['c']:
                WalkFix(y)
        else:
            if isinstance(x, list):
                for y in x:
                    WalkFix(y)

def TranslateAmpersand(lang):
    lang = re.sub('[-_].*', '', lang)
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

    WalkFix(j['blocks'])

    # Print the json representation of the new document
    sys.stdout.write(json.dumps(j))
