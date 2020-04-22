#!/usr/bin/env python3

"""
Adapted from code written by Hamed MP, published at
https://gist.github.com/HamedMP/03440cca542ee7ae279175b78499fabf
"""

import sys
import os
import re
import PyQt5
import popplerqt5

def main():

    doc = popplerqt5.Poppler.Document.load(sys.argv[1])
    if len(sys.argv) > 2:
        citekey = sys.argv[2]
    else:
        citekey = ''
    if len(sys.argv) > 3:
        page1 = int(sys.argv[3])
    else:
        page1 = 1
    if os.getenv('ZYearPageSep') is None:
        ypsep = ', p. '
    else:
        ypsep = os.getenv('ZYearPageSep')

    total_annotations = 0
    for i in range(doc.numPages()):
        page = doc.page(i)
        if page.label():
            pgnum = page.label()
        else:
            pgnum = str(i + page1)
        annotations = page.annotations()
        (pwidth, pheight) = (page.pageSize().width(), page.pageSize().height())
        if annotations:
            for a in annotations:
                if isinstance(a, popplerqt5.Poppler.Annotation):
                    total_annotations += 1
                    if a.contents():
                        txt = a.contents() + ' [annotation'
                        if a.author():
                            txt = txt + ' by ' + a.author()
                        if citekey:
                            txt = txt + ' on ' + citekey
                        txt = txt + ypsep + pgnum + ']\n'
                        print(txt)
                    if isinstance(a, popplerqt5.Poppler.HighlightAnnotation):
                        quads = a.highlightQuads()
                        txt = ''
                        for quad in quads:
                            rect = (quad.points[0].x() * pwidth,
                                    quad.points[0].y() * pheight,
                                    quad.points[2].x() * pwidth,
                                    quad.points[2].y() * pheight)
                            bdy = PyQt5.QtCore.QRectF()
                            bdy.setCoords(*rect)
                            txt = txt + str(page.text(bdy)) + ' '

                        txt = txt.replace('-\n', '')
                        txt = txt.replace('\n', ' ')
                        txt = re.sub('^ *', '', txt)
                        txt = re.sub(' *$', '', txt)
                        if txt:
                            txt = '> ' + txt + ' ['
                            if citekey:
                                txt = txt + citekey
                            txt = txt + ypsep + pgnum + ']\n'
                            print(txt)

    if total_annotations == 0:
        print("no annotations found")

if __name__ == "__main__":
    main()
