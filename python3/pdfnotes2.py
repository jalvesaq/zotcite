#!/usr/bin/env python3

"""
PDF annotation extraction tool for zotcite using PyMuPDF (fitz)
"""

import sys
import os
import re
import json
from datetime import datetime

try:
    import fitz  # PyMuPDF
except ImportError:
    sys.stdout.write("Please install the Python3 module pymupdf: pip install pymupdf")
    sys.exit(1)

def main():
    # Check arguments
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: pdfnotes.py PDF_FILE [CITEKEY] [PAGE_OFFSET]\n")
        sys.exit(1)
        
    # Load the PDF file
    try:
        doc = fitz.open(sys.argv[1])
    except Exception as e:
        sys.stderr.write(f"Error opening PDF: {e}\n")
        sys.exit(33)

    # Get the citation key if provided
    if len(sys.argv) > 2:
        citekey = sys.argv[2]
    else:
        citekey = ''

    # Get page offset
    page1 = 1
    has_pg_range = False
    if len(sys.argv) > 3:
        pg = sys.argv[3]
        try:
            # Check if it's a page range with hyphen
            if "-" in pg:
                has_pg_range = True
                pIni = int(re.sub("-.*", "", pg))
                pEnd = int(re.sub(".*-", "", pg))
                nPgs = pEnd - pIni + 1

                # Some documents have 1 or 2 extra presentation pages. Ignore them.
                if doc.page_count <= nPgs and (nPgs - doc.page_count) < 2:
                    page1 = pEnd - doc.page_count + 1
            else:
                # Try to convert to an integer
                try:
                    page1 = int(pg)
                except ValueError:
                    # Not a valid page number, might be a Zotero key passed by mistake
                    sys.stderr.write(f"Warning: Third argument '{pg}' is not a valid page number. Using default page 1.\n")
                    page1 = 1
        except Exception as e:
            # Catch any other errors in page number parsing
            sys.stderr.write(f"Warning: Error parsing page number: {e}. Using default page 1.\n")
            page1 = 1

    # Get year-page separator from environment
    if os.getenv('ZYearPageSep') is None:
        ypsep = ', p. '
    else:
        ypsep = os.getenv('ZYearPageSep')

    notes = []

    # Process each page
    for page_idx in range(doc.page_count):
        page = doc[page_idx]
        pnum = page_idx + 1
        
        # Handle page numbering
        pgnum = str(page_idx + page1)
        
        # Try to use page labels if available and not using a range
        if not has_pg_range:
            try:
                # Get page label if available (Roman numerals, etc.)
                if hasattr(doc, "get_page_labels"):
                    label = doc.get_page_labels()[page_idx]
                    if label and label.strip():
                        pgnum = label
            except:
                pass  # Fallback to numeric page

        # Get annotations
        annots = page.annots()
        if not annots:
            continue

        # Page dimensions for positioning
        pwidth, pheight = page.rect.width, page.rect.height
        
        # Process annotations on this page
        for annot in annots:
            # Get annotation type
            annot_type = annot.type[1]
            
            # Get coordinates for sorting (top of annotation)
            rect = annot.rect
            x, y = rect.x0, rect.y0
            
            # Guess column (for dual-column documents)
            c = 1 if x < (pwidth / 2) else 2
            
            # Get contents (annotation text)
            contents = annot.info.get("content", "")
            
            # Get author if available
            author = annot.info.get("title", "")
            
            # Process text comments/notes
            if contents and annot_type in ["Text", "FreeText", "Note"]:
                txt = contents + ' [annotation'
                if author:
                    txt += ' by ' + author
                if citekey:
                    txt += ' on ' + citekey
                txt += ypsep + pgnum + ']\n'
                
                # Add to notes list (with slight y-offset to ensure comments come before highlights)
                notes.append([pnum, c, y - 0.0000001, txt])
            
            # Process highlighted text
            if annot_type in ["Highlight", "Underline"]:
                # Extract text from the highlighted region
                text = ""
                
                # Try multiple methods to extract text
                try:
                    # Method 1: Get text using get_text with clip (most reliable method)
                    text = page.get_text("text", clip=rect)
                except Exception as e1:
                    try:
                        # Method 2: Use get_textbox if available (older versions)
                        if hasattr(page, "get_textbox"):
                            text = page.get_textbox(rect)
                    except Exception as e2:
                        try:
                            # Method 3: Extract words individually and combine
                            words = page.get_text("words")
                            for word in words:
                                if len(word) >= 5:  # Make sure it has all required fields
                                    word_rect = fitz.Rect(word[:4])
                                    if rect.intersects(word_rect):
                                        text += word[4] + " "
                        except Exception as e3:
                            # Method 4: Last resort - get all text and note we couldn't extract properly
                            try:
                                all_text = page.get_text("text")
                                if all_text:
                                    text = "[Highlighted text could not be extracted precisely]"
                            except Exception as e4:
                                # Unable to extract any text
                                pass
                
                # Clean up the text
                if text:
                    text = text.replace('-\n', '')
                    text = text.replace('\n', ' ')
                    text = re.sub(r'^\s*', '', text)
                    text = re.sub(r'\s*$', '', text)
                    text = re.sub(r'\s+', ' ', text)
                    
                    if text.strip():
                        txt = '> ' + text + ' ['
                        if citekey:
                            txt += citekey
                        txt += ypsep + pgnum + ']\n'
                        notes.append([pnum, c, y, txt])
    
    # Close the document
    doc.close()
    
    # Check if we found any notes
    if notes:
        # Sort notes by page, column, and y-position
        snotes = sorted(notes, key=lambda x: (x[0], x[1], x[2]))
        for n in snotes:
            print(n[3], end='')
    else:
        sys.stderr.write(f"No annotations found in the PDF: {sys.argv[1]}\n")
        sys.exit(34)

if __name__ == "__main__":
    main()
