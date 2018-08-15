""" Class ZoteroEntries """
import sys
import os
import re
import sqlite3

# A lot of code was either adapted or plainly copied from citation_vim,
# written by Rafael Schouten: https://github.com/rafaqz/citation.vim
# Code and/or ideas were also adapted from zotxt, pypandoc, and pandocfilters.

class ZoteroEntries:
    """ Create an object storing all references from ~/Zotero/zotero.sqlite """

    # Conversion from zotero.sqlite to CSL types
    _zct = {
        'artwork'             : 'graphic',
        'audioRecording'      : 'song',
        'blogPost'            : 'post-weblog',
        'bookSection'         : 'chapter',
        'case'                : 'legal_case',
        'computerProgram'     : 'book',
        'conferencePaper'     : 'paper-conference',
        'dictionaryEntry'     : 'entry-dictionary',
        'document'            : 'report',
        'email'               : 'personal_communication',
        'encyclopediaArticle' : 'entry-encyclopedia',
        'film'                : 'motion_picture',
        'forumPost'           : 'post',
        'hearing'             : 'bill',
        'instantMessage'      : 'personal_communication',
        'interview'           : 'interview',
        'journalArticle'      : 'article-journal',
        'letter'              : 'personal_communication',
        'magazineArticle'     : 'article-magazine',
        'newspaperArticle'    : 'article-newspaper',
        'note'                : 'manuscript',
        'podcast'             : 'broadcast',
        'presentation'        : 'speech',
        'radioBroadcast'      : 'broadcast',
        'statute'             : 'legislation',
        'tvBroadcast'         : 'broadcast',
        'videoRecording'      : 'motion_picture'}

    # Conversion from zotero.sqlite to CSL fields
    # It's incomplete and accuracy isn't guaranteed!
    _zcf = {
        'abstractNote'        : 'abstract',
        'accessDate'          : 'accessed',
        'applicationNumber'   : 'call-number',
        'archiveLocation'     : 'archive_location',
        'artworkMedium'       : 'medium',
        'artworkSize'         : 'dimensions',
        'audioFileType'       : 'medium',
        'blogTitle'           : 'container-title',
        'bookTitle'           : 'container-title',
        'callNumber'          : 'call-number',
        'code'                : 'container-title',
        'codeNumber'          : 'volume',
        'codePages'           : 'page',
        'codeVolume'          : 'volume',
        'conferenceName'      : 'event',
        'court'               : 'authority',
        'date'                : 'issued',
        'dictionaryTitle'     : 'container-title',
        'distributor'         : 'publisher',
        'encyclopediaTitle'   : 'container-title',
        'extra'               : 'note',
        'filingDate'          : 'submitted',
        'forumTitle'          : 'container-title',
        'history'             : 'references',
        'institution'         : 'publisher',
        'interviewMedium'     : 'medium',
        'issuingAuthority'    : 'authority',
        'legalStatus'         : 'status',
        'legislativeBody'     : 'authority',
        'libraryCatalog'      : 'source',
        'meetingName'         : 'event',
        'numPages'            : 'number-of-pages',
        'numberOfVolumes'     : 'number-of-volumes',
        'pages'               : 'page',
        'place'               : 'publisher-place',
        'priorityNumbers'     : 'issue',
        'proceedingsTitle'    : 'container-title',
        'programTitle'        : 'container-title',
        'programmingLanguage' : 'genre',
        'publicationTitle'    : 'container-title',
        'reporter'            : 'container-title',
        'runningTime'         : 'dimensions',
        'series'              : 'collection-title',
        'seriesNumber'        : 'collection-number',
        'seriesTitle'         : 'collection-title',
        'session'             : 'chapter-number',
        'shortTitle'          : 'title-short',
        'system'              : 'medium',
        'thesisType'          : 'genre',
        'type'                : 'genre',
        'university'          : 'publisher',
        'url'                 : 'URL',
        'versionNumber'       : 'version',
        'websiteTitle'        : 'container-title',
        'websiteType'         : 'genre'}

    # Conversion from zotero.sqlite to bib types
    _zbt = {
        'artwork'             : 'Misc',
        'audioRecording'      : 'Misc',
        'blogPost'            : 'Misc',
        'book'                : 'Book',
        'bookSection'         : 'InCollection',
        'case'                : 'Misc',
        'computerProgram'     : 'Book',
        'conferencePaper'     : 'InProceedings',
        'dictionaryEntry'     : 'InCollection',
        'document'            : 'TechReport',
        'email'               : 'Misc',
        'encyclopediaArticle' : 'InCollection',
        'film'                : 'Misc',
        'forumPost'           : 'Misc',
        'hearing'             : 'Misc',
        'instantMessage'      : 'Misc',
        'interview'           : 'Misc',
        'journalArticle'      : 'Article',
        'letter'              : 'Misc',
        'magazineArticle'     : 'Article',
        'newspaperArticle'    : 'Article',
        'note'                : 'Misc',
        'podcast'             : 'Misc',
        'presentation'        : 'Misc',
        'radioBroadcast'      : 'Misc',
        'statute'             : 'Misc',
        'thesis'              : 'Thesis',
        'tvBroadcast'         : 'Misc',
        'videoRecording'      : 'Misc'}

    # Conversion from zotero.sqlite to bib fields
    # It's incomplete and accuracy isn't guaranteed!
    _zbf = {
        'abstractNote'        : 'abstract',
        'accessDate'          : 'urldate',
        'applicationNumber'   : 'call-number',
        'archiveLocation'     : 'archive_location',
        'artworkMedium'       : 'medium',
        'artworkSize'         : 'dimensions',
        'attachment'          : 'file',
        'audioFileType'       : 'medium',
        'blogTitle'           : 'booktitle',
        'bookTitle'           : 'booktitle',
        'callNumber'          : 'call-number',
        'code'                : 'booktitle',
        'codeNumber'          : 'volume',
        'codePages'           : 'pages',
        'codeVolume'          : 'volume',
        'conferenceName'      : 'event',
        'court'               : 'authority',
        'date'                : 'issued',
        'dictionaryTitle'     : 'booktitle',
        'distributor'         : 'publisher',
        'encyclopediaTitle'   : 'booktitle',
        'extra'               : 'note',
        'filingDate'          : 'submitted',
        'forumTitle'          : 'booktitle',
        'genre'               : 'type',
        'history'             : 'references',
        'institution'         : 'publisher',
        'interviewMedium'     : 'medium',
        'issue'               : 'number',
        'issuingAuthority'    : 'authority',
        'legalStatus'         : 'status',
        'legislativeBody'     : 'authority',
        'libraryCatalog'      : 'source',
        'meetingName'         : 'event',
        'numPages'            : 'pages',
        'numberOfVolumes'     : 'volume',
        'place'               : 'address',
        'priorityNumbers'     : 'issue',
        'proceedingsTitle'    : 'booktitle',
        'programTitle'        : 'booktitle',
        'programmingLanguage' : 'type',
        'publicationTitle'    : 'booktitle',
        'reporter'            : 'booktitle',
        'runningTime'         : 'dimensions',
        'seriesNumber'        : 'number',
        'session'             : 'chapter-number',
        'shortTitle'          : 'shorttitle',
        'system'              : 'medium',
        'thesisType'          : 'type',
        'university'          : 'publisher',
        'url'                 : 'URL',
        'versionNumber'       : 'version',
        'websiteTitle'        : 'booktitle',
        'websiteType'         : 'type'}

    def __init__(self):

        # Template for citation keys
        self._cite = os.getenv('ZCitationTemplate')
        if self._cite is None:
            self._cite = '{Author}_{Year}'

        # Title words to be ignored
        self._bwords = os.getenv('ZBannedWords')
        if self._bwords is None:
            self._bwords = 'a an the some from on in to of do with'

        # Bib entries by collection
        self._e = {}

        # Temporary list of entries
        self._t = {}

        # Path of zotero.sqlite
        if os.getenv('ZoteroSQLpath') is None:
            if os.path.isfile(os.getenv('HOME') + '/Zotero/zotero.sqlite'):
                self._z = os.getenv('HOME') + '/Zotero/zotero.sqlite'
            else:
                self._errmsg('The file zotero.sqlite3 was not found. Please, define the environment variable ZoteroSQLpath.')
                return None
        else:
            if os.path.isfile(os.path.expanduser(os.getenv('ZoteroSQLpath'))):
                self._z = os.path.expanduser(os.getenv('ZoteroSQLpath'))
            else:
                self._errmsg('Please, check if $ZoteroSQLpath is correct: "' + os.getenv('ZoteroSQLpath') + '" not found.')
                return None

        # Temporary directory
        if os.getenv('Zotcite_tmpdir') is None:
            if os.getenv('XDG_CACHE_HOME') and os.path.isdir(os.getenv('XDG_CACHE_HOME')):
                self._tmpdir = os.getenv('XDG_CACHE_HOME') + '/zotcite'
            elif os.getenv('APPDATA') and os.path.isdir(os.getenv('APPDATA')):
                self._tmpdir = os.getenv('APPDATA') + '/zotcite'
            elif os.path.isdir(os.path.expanduser('~/.cache')):
                self._tmpdir = os.path.expanduser('~/.cache/zotcite')
            elif os.path.isdir(os.path.expanduser('~/Library/Caches')):
                self._tmpdir = os.path.expanduser('~/Library/Caches/zotcite')
            else:
                self._tmpdir = '/tmp/.zotcite'
        else:
            self._tmpdir = os.path.expanduser(os.getenv('Zotcite_tmpdir'))
        if not os.path.isdir(self._tmpdir):
            try:
                os.mkdir(self._tmpdir)
            except:
                self._exception()
                return None
        if not os.access(self._tmpdir, os.W_OK):
            self._errmsg('Please, either set or fix the value of $Zotcite_tmpdir: "' + self._tmpdir + '" is not writable.')
            return None

        self._load_zotero_data()

        # List of collections for each markdown document
        self._d = {}

    def SetCollections(self, d, clist):
        """ Define which Zotero collections each markdown document uses

            d   (string): The name of the markdown document
            clist (list): A list of collections to be searched for citation keys
                          when seeking references for the document 'd'.
        """

        self._d[d] = []
        if clist == ['']:
            for k in self._e:
                self._d[d].append(k)
        else:
            self._d[d] = []
            for c in clist:
                if c in self._e:
                    self._d[d].append(c)
                else:
                    return 'Collection "' + c + '" not found in Zotero database.'
        return ''


    def _load_zotero_data(self):
        self._ztime = os.path.getmtime(self._z)
        zcopy = self._tmpdir + '/copy_of_zotero.sqlite'
        if os.path.isfile(zcopy):
            zcopy_time = os.path.getmtime(zcopy)
        else:
            zcopy_time = 0

        # Make a copy of zotero.sqlite to avoid locks
        if self._ztime > zcopy_time:
            with open(self._z, 'rb') as f:
                b = f.read()
            with open(zcopy, 'wb') as f:
                f.write(b)

        conn = sqlite3.connect(zcopy)
        self._cur = conn.cursor()
        self._add_most_fields()
        self._add_collection()
        self._add_authors()
        self._add_type()
        self._add_note()
        self._add_tags() # Not used yet
        self._add_attachments()
        self._calculate_citekeys()
        self._separate_by_collection()
        conn.close()


    def _add_most_fields(self):
        query = u"""
            SELECT items.itemID, items.key, fields.fieldName, itemDataValues.value
            FROM items, itemData, fields, itemDataValues
            WHERE
                items.itemID = itemData.itemID
                and itemData.fieldID = fields.fieldID
                and itemData.valueID = itemDataValues.valueID
            """
        self._t = {}
        self._cur.execute(query)
        for item_id, item_key, field, value in self._cur.fetchall():
            if item_id not in self._t:
                self._t[item_id] = {'zotkey': item_key, 'collection': None, 'alastnm': '', 'tags': []}
            self._t[item_id][field] = value

    def _add_collection(self):
        query = u"""
            SELECT items.itemID, collections.collectionName
            FROM items, collections, collectionItems
            WHERE
                items.itemID = collectionItems.itemID
                and collections.collectionID = collectionItems.collectionID
            ORDER by collections.collectionName != "To Read",
                collections.collectionName
            """
        self._cur.execute(query)
        for item_id, item_collection in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['collection'] = item_collection

    def _add_authors(self):
        query = u"""
            SELECT items.itemID, creatorTypes.creatorType, creators.lastName, creators.firstName
            FROM items, itemCreators, creators, creatorTypes
            WHERE
                items.itemID = itemCreators.itemID
                and itemCreators.creatorID = creators.creatorID
                and creators.creatorID = creators.creatorID
                and itemCreators.creatorTypeID = creatorTypes.creatorTypeID
            ORDER by itemCreators.ORDERIndex
            """
        self._cur.execute(query)
        for item_id, ctype, lastname, firstname in self._cur.fetchall():
            if item_id in self._t:
                if ctype in self._t[item_id]:
                    self._t[item_id][ctype] += [[lastname, firstname]]
                else:
                    self._t[item_id][ctype] = [[lastname, firstname]]
                # Special field for citation seeking
                if ctype == 'author':
                    self._t[item_id]['alastnm'] += ', ' + lastname

    def _add_type(self):
        query = u"""
            SELECT items.itemID, itemTypes.typeName
            FROM items, itemTypes
            WHERE
                items.itemTypeID = itemTypes.itemTypeID
            """
        self._cur.execute(query)
        for item_id, item_type in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['etype'] = item_type

    def _add_note(self):
        query = u"""
            SELECT itemNotes.parentItemID, itemNotes.note
            FROM itemNotes
            WHERE
                itemNotes.parentItemID IS NOT NULL;
            """
        self._cur.execute(query)
        for item_id, item_note in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['note'] = item_note

    def _add_tags(self):
        query = u"""
            SELECT items.itemID, tags.name
            FROM items, tags, itemTags
            WHERE
                items.itemID = itemTags.itemID
                and tags.tagID = itemTags.tagID
            """
        self._cur.execute(query)
        for item_id, item_tag in self._cur.fetchall():
            if item_id in self._t:
                self._t[item_id]['tags'] += [item_tag]

    def _add_attachments(self):
        query = u"""
            SELECT items.key, itemAttachments.parentItemID, itemAttachments.path
            FROM items, itemAttachments
            WHERE items.itemID = itemAttachments.itemID
            """
        self._cur.execute(query)
        for pKey, pId, aPath in self._cur.fetchall():
            self._t[pId]['attachment'] = pKey + ':' + aPath

    def _calculate_citekeys(self):
        ptrn = '^(' + ' |'.join(self._bwords) + ' )'
        for k in self._t:
            if 'date' in self._t[k]:
                year = re.sub(' .*', '', self._t[k]['date']).split('-')[0]
            else:
                year = ''
            self._t[k]['year'] = year
            if 'title' in self._t[k]:
                title = re.sub(ptrn, '', self._t[k]['title'].lower())
                title = re.sub('^[a-z] ', '', title)
                titlew = re.sub('[ ,;:\.!?].*', '', title)
            else:
                self._t[k]['title'] = ''
                titlew = ''
            if 'author' in self._t[k]:
                lastname = self._t[k]['author'][0][0]
            else:
                lastname = 'No_author'
            lastname = re.sub('\W', '', lastname)
            titlew = re.sub('\W', '', titlew)
            key = self._cite
            key = re.sub('{author}', lastname.lower(), key)
            key = re.sub('{Author}', lastname.title(), key)
            key = re.sub('{year}', re.sub('^[0-9][0-9]', '', year), key)
            key = re.sub('{Year}', year, key)
            key = re.sub('{title}', titlew.lower(), key)
            key = re.sub('{Title}', titlew.title(), key)
            key = re.sub(' ', '', key)
            self._t[k]['citekey'] = key


    def _separate_by_collection(self):
        self._cur.execute(u"SELECT itemID FROM deletedItems")
        d = []
        for item_id, in self._cur.fetchall():
            d.append(item_id)

        self._e = {}
        for k in self._t:
            if k in d or self._t[k]['etype'] == 'attachment':
                continue
            self._t[k]['alastnm'] = re.sub('^, ', '', self._t[k]['alastnm'])
            if self._t[k]['collection'] not in self._e:
                self._e[self._t[k]['collection']] = {}
            self._e[self._t[k]['collection']][str(k)] = self._t[k]

    @classmethod
    def _errmsg(cls, msg):
        sys.stderr.write(msg + '\n')
        sys.stderr.flush()

    def _exception(self):
        import traceback
        exc_type, exc_value, exc_traceback = sys.exc_info()
        lines = traceback.format_exception(exc_type, exc_value, exc_traceback)
        self._errmsg("Zotcite error: " + "".join(line for line in lines))

    @classmethod
    def _get_compl_line(cls, e):
        if e['alastnm'] == '':
            line = e['zotkey'] + '#' + e['citekey'] + '\x09 \x09(' + e['year'] + ') ' + e['title']
        else:
            line = e['zotkey'] + '#' + e['citekey'] + '\x09' + e['alastnm'] + '\x09(' + e['year'] + ') ' + e['title']
        return line

    def GetMatch(self, ptrn, d):
        """ Find citation key and save completion lines in temporary file

            ptrn (string): The pattern to search for, converted to lower case.
            d    (string): The name of the markdown document.
        """
        if os.path.getmtime(self._z) > self._ztime:
            self._load_zotero_data()

        collections = self._d[d]
        if collections == []:
            collections = self._e.keys()

        # priority level
        p1 = []
        p2 = []
        p3 = []
        p4 = []
        p5 = []
        p6 = []
        for c in collections:
            for k in self._e[c]:
                if self._e[c][k]['citekey'].lower().find(ptrn) == 0:
                    p1.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['alastnm'] and self._e[c][k]['alastnm'][0][0].lower().find(ptrn) == 0:
                    p2.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['title'].lower().find(ptrn) == 0:
                    p3.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['citekey'].lower().find(ptrn) > 0:
                    p4.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['alastnm'] and self._e[c][k]['alastnm'][0][0].lower().find(ptrn) > 0:
                    p5.append(self._get_compl_line(self._e[c][k]))
                elif self._e[c][k]['title'].lower().find(ptrn) > 0:
                    p6.append(self._get_compl_line(self._e[c][k]))
        resp = p1 + p2 + p3 + p4 + p5 + p6
        return resp

    def _get_yaml_ref(self, e, citekey):
        # Fix the type
        if e['etype'] in self._zct:
            e['etype'] = e['etype'].replace(e['etype'], self._zct[e['etype']])
        # Escape quotes of all fields and rename some fields
        for f in e:
            if isinstance(e[f], str):
                e[f] = re.sub('"', '\\"', e[f])
        ekeys = list(e.keys())
        for f in ekeys:
            if f in self._zcf:
                e[self._zcf[f]] = e.pop(f)

        ref = '- type: ' + e['etype'] + '\n  id: ' + citekey + '\n'
        for aa in ['author', 'editor', 'contributor', 'translator',
                   'container-author']:
            if aa in e:
                ref += '  ' + aa + ':\n'
                for last, first in e[aa]:
                    ref += '  - family: "' + last + '"\n'
                    ref += '    given: "' + first + '"\n'
        if 'issued' in e:
            d = re.sub(' .*', '', e['issued']).split('-')
            if d[0] != '0000':
                ref += '  issued:\n    year: ' + e['year'] + '\n'
                if d[1] != '00':
                    ref += '    month: ' + d[1] + '\n'
                if d[2] != '00':
                    ref += '    day: ' + d[2] + '\n'
        dont = ['etype', 'issued', 'abstract', 'citekey', 'zotkey',
                'collection', 'author', 'editor', 'contributor', 'translator',
                'alastnm', 'container-author', 'tags', 'year']
        for f in e:
            if f not in dont:
                ref += '  ' + f + ': "' + str(e[f]) + '"\n'
        return ref

    def GetYamlRefs(self, keys):
        """ Build a dummy Markdown document with the references in the YAML header

            keys (list): List of citation keys (not Zotero keys) present in the document.
        """

        ref = ''
        for c in self._e:
            for e in self._e[c]:
                for k in keys:
                    zotkey = re.sub('#.*', '', k)
                    if zotkey == self._e[c][e]['zotkey']:
                        ref += self._get_yaml_ref(self._e[c][e], k)
        if ref != '':
            ref = '---\nreferences:\n' + ref + '...\n\ndummy text\n'
        return ref

    def _get_bib_ref(self, e, citekey):
        # Fix the type
        if e['etype'] in self._zbt:
            e['etype'] = e['etype'].replace(e['etype'], self._zbt[e['etype']])
        # Escape quotes of all fields and rename some fields
        for f in e:
            if isinstance(e[f], str):
                e[f] = re.sub('"', '\\"', e[f])
        ekeys = list(e.keys())
        for f in ekeys:
            if f in self._zbf:
                e[self._zbf[f]] = e.pop(f)

        if e['etype'] == 'Article' and 'booktitle' in e:
            e['journal'] = e.pop('booktitle')
        if e['etype'] == 'InCollection' and not 'editor' in e:
            e['etype'] = 'InBook'

        ref = '\n@' + e['etype'] + '{' + citekey + ',\n'
        for aa in ['author', 'editor', 'contributor', 'translator',
                   'container-author']:
            if aa in e:
                names = []
                ref += '  ' + aa + ' = {'
                for last, first in e[aa]:
                    names.append(last + ', ' + first)
                ref += ' and '.join(names) + '},\n'
        if 'issued' in e:
            d = re.sub(' .*', '', e['issued']).split('-')
            if d[0] != '0000':
                ref += '  year = {' + e['year'] + '},\n'
                if d[1] != '00':
                    ref += '  month = {' + d[1] + '},\n'
                if d[2] != '00':
                    ref += '  day = {' + d[2] + '},\n'
        dont = ['etype', 'issued', 'abstract', 'citekey', 'zotkey',
                'collection', 'author', 'editor', 'contributor', 'translator',
                'alastnm', 'container-author', 'tags', 'year']
        for f in e:
            if f not in dont:
                ref += '  ' + f + ' = {' + str(e[f]) + '},\n'
        ref += '}\n'
        return ref

    def GetBib(self, keys):
        """ Build the contents of a .bib file

            keys (list): List of citation keys (not Zotero keys) present in the document.
        """

        ref = ''
        for c in self._e:
            for e in self._e[c]:
                for k in keys:
                    zotkey = re.sub('#.*', '', k)
                    if zotkey == self._e[c][e]['zotkey']:
                        ref += self._get_bib_ref(self._e[c][e], k)
        return ref

    def GetAttachment(self, zotkey):
        """ Tell Vim what attachment is associated with the citation key

            zotkey  (string): The Zotero key as it appears in the markdown document.
        """

        for c in self._e:
            for k in self._e[c]:
                if self._e[c][k]['zotkey'] == zotkey:
                    if 'attachment' in self._e[c][k]:
                        return self._e[c][k]['attachment']
                    return "nOaTtAChMeNt"
        return "nOcItEkEy"

    def GetRefData(self, zotkey):
        """ Return the key's dictionary.

            zotkey  (string): The Zotero key as it appears in the markdown document.
        """

        for c in self._e:
            for k in self._e[c]:
                if self._e[c][k]['zotkey'] == zotkey:
                    return self._e[c][k]
        return "NoCiteKey"

    def Info(self):
        """ Return information that might be useful for users of ZoteroEntries """

        n = 0
        for c in self._e:
            n += len(self._e[c].keys())
        r = {'zotero.py': os.path.realpath(__file__),
             'zotero.sqlite': self._z,
             'tmpdir': self._tmpdir,
             'references found': n,
             'docs': str(self._d) + '\n',
             'citation template': self._cite,
             'banned words': self._bwords,
            }
        return r
