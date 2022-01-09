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
    if doc is None:
        sys.exit(33)

    if len(sys.argv) > 2:
        citekey = sys.argv[2]
    else:
        citekey = ''

    # Sometimes, the page labels are spurious. So the priority is:
    # 1. given page range; 2. page label; 3. given starting page.
    page1 = 1
    has_pg_range = False
    if len(sys.argv) > 3:
        pg = sys.argv[3]
        if pg.find("-"):
            has_pg_range = True
            pIni = int(re.sub("-.*", "", pg))
            pEnd = int(re.sub(".*-", "", pg))
            nPgs = pEnd - pIni + 1

            # Some documents have 1 or 2 extra presentation pages. Ignore them.
            if doc.numPages() <= nPgs and (nPgs - doc.numPages()) < 2:
                page1 = pEnd - doc.numPages() + 1
        else:
            page1 = int(sys.argv[3])

    if os.getenv('ZYearPageSep') is None:
        ypsep = ', p. '
    else:
        ypsep = os.getenv('ZYearPageSep')

    notes = []

    # Count the pages because not all page labels can be easily converted into
    # numbers (examples: A1 and III)
    pnum = 0

    for i in range(doc.numPages()):
        page = doc.page(i)
        pnum += 1
        pgnum = str(i + page1)
        if not has_pg_range and page.label():
            pgnum = page.label()

        annotations = page.annotations()
        (pwidth, pheight) = (page.pageSize().width(), page.pageSize().height())
        if annotations:
            for a in annotations:
                if isinstance(a, popplerqt5.Poppler.Annotation):
                    # Get the y coordinate to be able to print the annotations
                    # in the correct order
                    y = a.boundary().topRight().y()

                    if a.contents():
                        txt = a.contents() + ' [annotation'
                        if a.author():
                            txt = txt + ' by ' + a.author()
                        if citekey:
                            txt = txt + ' on ' + citekey
                        txt = txt + ypsep + pgnum + ']\n'

                        # Decrease the value of y to ensure that the comment
                        # on a highlighted text will be printed before the
                        # highlighted text itself
                        notes.append([pnum, y - 0.0000001, txt])

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
                            txt = txt + str(page.text(bdy)) + '\n'

                        txt = txt.replace('-\n', '')
                        txt = txt.replace('\n', ' ')
                        txt = re.sub('^ *', '', txt)
                        txt = re.sub(' *$', '', txt)
                        if txt:
                            txt = '> ' + txt + ' ['
                            if citekey:
                                txt = txt + citekey
                            txt = txt + ypsep + pgnum + ']\n'
                            notes.append([pnum, y, txt])

    if notes:
        snotes = sorted(notes, key=lambda x: (x[0], x[1]))
        for n in snotes:
            print(n[2])
    else:
        sys.exit(34)

if __name__ == "__main__":
    main()
