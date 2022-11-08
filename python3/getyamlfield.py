#!/usr/bin/env python3

"""
Filter to get YAML field from stdin
"""

import sys
import io
import yaml

if __name__ == "__main__":
    i = sys.stdin.read()
    y = yaml.load(io.StringIO(i), yaml.BaseLoader)
    if sys.argv[1] in y.keys():
        v = y[sys.argv[1]]
    else:
        v = []
    if isinstance(v, str):
        v = v.replace('"', '\\"')
        print('"' + v + '"')
    else:
        print(str(v))
