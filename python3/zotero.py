""" Class ZoteroEntries """
import sys
import os
import re
import sqlite3
import copy

# A lot of code was either adapted or plainly copied from citation_vim,
# written by Rafael Schouten: https://github.com/rafaqz/citation.vim
# Code and/or ideas were also adapted from zotxt, pypandoc, and pandocfilters.

# To debug this code, create a /tmp/test.md file and do:
# pandoc testzotcite.md -t json | /full/path/to/zotcite/python3/zotref

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
        'issueDate'           : 'issued',
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
        'reviewedAuthor'      : 'reviewed-author',
        'runningTime'         : 'dimensions',
        'series'              : 'collection-title',
        'seriesEditor'        : 'collection-editor',
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
        'issueDate'           : 'issued',
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

    _creators = ["editor", "seriesEditor", "translator", "reviewedAuthor",
                 "artist", "performer", "composer", "director", "podcaster",
                 "cartographer", "programmer", "presenter", "interviewee",
                 "interviewer", "recipient", "sponsor", "inventor"]
    def __init__(self):

        # Template for citation keys
        self._cite = os.getenv('ZCitationTemplate')
        if self._cite is None:
            self._cite = '{Authors}_{Year}'

        # Title words to be ignored
        self._bwords = os.getenv('ZBannedWords')
        if self._bwords is None:
            self._bwords = 'a an the some from on in to of do with'

        # Path to zotero.sqlite
        if os.getenv('ZoteroSQLpath') is None:
            if os.path.isfile(os.path.expanduser('~/Zotero/zotero.sqlite')):
                self._z = os.path.expanduser('~/Zotero/zotero.sqlite')
            elif os.path.isfile(os.getenv('USERPROFILE') + '/Zotero/zotero.sqlite'):
                self._z = os.getenv('USERPROFILE') + '/Zotero/zotero.sqlite'
            else:
                self._errmsg('The file zotero.sqlite was not found. Please, define the environment variable ZoteroSQLpath.')
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

        # Fields that should not be added to the YAML references:
        if os.getenv('Zotcite_exclude') is None:
            self._exclude = []
        else:
            self._exclude = os.getenv('Zotcite_exclude').split()

        self._c = {}
        self._e = {}
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
        if clist != ['']:
            for c in clist:
                if c in self._c:
                    self._d[d].append(c)
                else:
                    return 'Collection "' + c + '" not found in Zotero database.'
        return ''


    def _copy_zotero_data(self):
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
        return zcopy

    def _load_zotero_data(self):
        zcopy = self._copy_zotero_data()
        conn = sqlite3.connect(zcopy)
        self._cur = conn.cursor()
        self._get_collections()
        self._add_most_fields()
        self._add_authors()
        self._add_type()
        self._add_attachments()
        self._calculate_citekeys()
        self._delete_items()
        conn.close()

        # Debug:
        #ckeys = []
        #with open('/tmp/ZData', 'w') as f:
        #    for c in self._c:
        #        ckeys += self._c[c]
        #        f.write(str(c) + ':\n')
        #        for k in self._c[c]:
        #            f.write('  ' + str(self._e[k]) + '\n')
        #    f.write('None:\n')
        #    for k in self._e:
        #        if k not in ckeys:
        #            f.write('  ' + str(self._e[k]) + '\n')


    def _get_collections(self):
        self._c = {}
        query = """
            SELECT collections.collectionName
            FROM collections
            """
        self._cur.execute(query)
        for c, in self._cur.fetchall():
            self._c[c] = []
        query = """
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
            self._c[item_collection].append(item_id)

    def _add_most_fields(self):
        query = u"""
            SELECT items.itemID, items.key, fields.fieldName, itemDataValues.value
            FROM items, itemData, fields, itemDataValues
            WHERE
                items.itemID = itemData.itemID
                and itemData.fieldID = fields.fieldID
                and itemData.valueID = itemDataValues.valueID
            """
        self._e = {}
        self._cur.execute(query)
        for item_id, item_key, field, value in self._cur.fetchall():
            if item_id not in self._e:
                self._e[item_id] = {'zotkey': item_key, 'alastnm': ''}
            self._e[item_id][field] = value

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
            if item_id in self._e:
                if ctype in self._e[item_id]:
                    self._e[item_id][ctype] += [[lastname, firstname]]
                else:
                    self._e[item_id][ctype] = [[lastname, firstname]]
                # Special field for citation seeking
                if ctype == 'author':
                    self._e[item_id]['alastnm'] += ', ' + lastname
                else:
                    sought = ['author']
                    for c in self._creators:
                        if ctype == c:
                            flag = False
                            for s in sought:
                                if s in self._e[item_id]:
                                    flag = True
                                    break
                            if not flag:
                                self._e[item_id]['alastnm'] += ', ' + lastname
                        sought.append(c)

    def _add_type(self):
        query = u"""
            SELECT items.itemID, itemTypes.typeName
            FROM items, itemTypes
            WHERE
                items.itemTypeID = itemTypes.itemTypeID
            """
        self._cur.execute(query)
        for item_id, item_type in self._cur.fetchall():
            if item_id in self._e:
                if item_type == 'attachment':
                    del self._e[item_id]
                else:
                    self._e[item_id]['etype'] = item_type

    def _add_attachments(self):
        query = u"""
            SELECT items.key, itemAttachments.parentItemID, itemAttachments.path
            FROM items, itemAttachments
            WHERE items.itemID = itemAttachments.itemID
            """
        self._cur.execute(query)
        for pKey, pId, aPath in self._cur.fetchall():
            if pId in self._e and not pKey is None and not aPath is None:
                if 'attachment' in self._e[pId]:
                    self._e[pId]['attachment'].append(pKey + ':' + aPath)
                else:
                    self._e[pId]['attachment'] = [pKey + ':' + aPath]

    def _calculate_citekeys(self):
        ptrn = '^(' + ' |'.join(self._bwords) + ' )'
        for k in self._e:
            if 'date' in self._e[k]:
                year = re.sub(' .*', '', self._e[k]['date']).split('-')[0]
            else:
                if 'issueDate' in self._e[k]:
                    year = re.sub(' .*', '', self._e[k]['issueDate']).split('-')[0]
                else:
                    year = ''
            self._e[k]['year'] = year
            if 'title' in self._e[k]:
                title = re.sub(ptrn, '', self._e[k]['title'].lower())
                title = re.sub('^[a-z] ', '', title)
                titlew = re.sub('[ ,;:\.!?].*', '', title)
            else:
                self._e[k]['title'] = ''
                titlew = ''
            lastname = 'No_author'
            lastnames = ''
            creators = ['author'] + self._creators
            for c in creators:
                if c in self._e[k]:
                    lastname = self._e[k][c][0][0]
                    for ln in self._e[k][c]:
                        lastnames = lastnames + '_' + ln[0]
                    break
            if lastnames == '':
                lastnames = 'No_author'

            lastnames = re.sub('^_', '', lastnames)
            lastnames = re.sub('_.*_.*_.*', '_etal', lastnames)
            lastname = re.sub('\W', '', lastname)
            titlew = re.sub('\W', '', titlew)
            key = self._cite
            key = key.replace('{author}', lastname.lower(), 1)
            key = key.replace('{Author}', lastname.title(), 1)
            key = key.replace('{authors}', lastnames.lower(), 1)
            key = key.replace('{Authors}', lastnames.title(), 1)
            key = key.replace('{year}', re.sub('^[0-9][0-9]', '', year), 1)
            key = key.replace('{Year}', year, 1)
            key = key.replace('{title}', titlew.lower(), 1)
            key = key.replace('{Title}', titlew.title(), 1)
            key = key.replace(' ', '', 1)
            self._e[k]['citekey'] = key


    def _delete_items(self):
        self._cur.execute(u"SELECT itemID FROM deletedItems")
        for item_id, in self._cur.fetchall():
            if item_id in self._e:
                del self._e[item_id]
            for c in self._c:
                if item_id in self._c[c]:
                    self._c[c].remove(item_id)

        for k in self._e:
            self._e[k]['alastnm'] = re.sub('^, ', '', self._e[k]['alastnm'])

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
        alastnm = e['alastnm']
        if alastnm == '':
            line = e['zotkey'] + '#' + e['citekey'] + '\x09 \x09(' + e['year'] + ') ' + e['title']
        else:
            if len(alastnm) > 40:
                alastnm = alastnm[:40] + "…"
            line = e['zotkey'] + '#' + e['citekey'] + '\x09' + alastnm + '\x09(' + e['year'] + ') ' + e['title']
        return line

    def GetMatch(self, ptrn, d):
        """ Find citation key and save completion lines in temporary file

            ptrn (string): The pattern to search for, converted to lower case.
            d    (string): The name of the markdown document.
        """
        if os.path.getmtime(self._z) > self._ztime:
            self._load_zotero_data()

        if d in self._d and self._d[d]:
            collections = self._d[d]
            keys = []
            for c in collections:
                if c in self._c:
                    keys += self._c[c]
            if keys == []:
                keys = self._e.keys()
        else:
            keys = self._e.keys()

        # priority level
        p1 = []
        p2 = []
        p3 = []
        p4 = []
        p5 = []
        p6 = []
        ptrn = ptrn.lower()
        for k in keys:
            if self._e[k]['citekey'].lower().find(ptrn) == 0:
                p1.append(self._get_compl_line(self._e[k]))
            elif self._e[k]['alastnm'] and self._e[k]['alastnm'][0][0].lower().find(ptrn) == 0:
                p2.append(self._get_compl_line(self._e[k]))
            elif self._e[k]['title'].lower().find(ptrn) == 0:
                p3.append(self._get_compl_line(self._e[k]))
            elif self._e[k]['citekey'].lower().find(ptrn) > 0:
                p4.append(self._get_compl_line(self._e[k]))
            elif self._e[k]['alastnm'] and self._e[k]['alastnm'][0][0].lower().find(ptrn) > 0:
                p5.append(self._get_compl_line(self._e[k]))
            elif self._e[k]['title'].lower().find(ptrn) > 0:
                p6.append(self._get_compl_line(self._e[k]))
        resp = p1 + p2 + p3 + p4 + p5 + p6
        return resp

    def _get_yaml_ref(self, entry, citekey):
        e = copy.deepcopy(entry)

        # Fix the type
        if e['etype'] in self._zct:
            e['etype'] = e['etype'].replace(e['etype'], self._zct[e['etype']])

        # https://www.zotero.org/support/kb/item_types_and_fields#item_creators
        # Fix author type:
        atype = ["artist", "performer", "director", "podcaster",
                 "cartographer", "programmer", "presenter",
                 "interviewee", "sponsor", "inventor"]
        for a in atype:
            if a in e and not 'author' in e:
                e['author'] = e.pop(a)

        # Rename some fields
        ekeys = list(e.keys())
        for f in ekeys:
            if f in self._zcf:
                e[self._zcf[f]] = e.pop(f)

        ref = '  - type: "' + e['etype'] + '"\n    id: "' + citekey + '"\n'
        atype = ["author", "editor", "collection-editor", "translator",
                 "reviewed-author", "composer", "interviewer", "recipient"]
        for aa in atype:
            if aa in e:
                ref += '    ' + aa + ':\n'
                for last, first in e[aa]:
                    ref += '      - family: "' + last + '"\n'
                    ref += '        given: "' + first + '"\n'
        if 'issued' in e:
            d = re.sub(' .*', '', e['issued']).split('-')
            if d[0] != '0000':
                ref += '    issued:\n      - year: "' + e['year'] + '"\n'
                if d[1] != '00':
                    ref += '        month: "' + d[1] + '"\n'
                if d[2] != '00':
                    ref += '        day: "' + d[2] + '"\n'
        dont = ['etype', 'issued', 'abstract', 'citekey', 'zotkey', 'collection',
                'alastnm', 'container-author', 'year'] + self._exclude + atype
        for f in e:
            if f not in dont:
                # Escape quotes of all fields
                ref += '    ' + f + ': "' + re.sub('"', '\\"', str(e[f])) + '"\n'
        return ref

    def GetYamlRefs(self, keys):
        """ Build a dummy Markdown document with the references in the YAML header

            keys (list): List of citation keys (not Zotero keys) present in the document.
        """

        ref = ''
        for e in self._e:
            for k in keys:
                zotkey = re.sub('#.*', '', k)
                if zotkey == self._e[e]['zotkey']:
                    ref += self._get_yaml_ref(self._e[e], k)
        if ref != '':
            ref = 'references:\n' + ref
        return ref

    def _get_bib_ref(self, entry, citekey):
        e = copy.deepcopy(entry)

        # Fix the type
        if e['etype'] in self._zbt:
            e['etype'] = e['etype'].replace(e['etype'], self._zbt[e['etype']])

        # Escape quotes of all fields
        for f in e:
            if isinstance(e[f], str):
                e[f] = re.sub('"', '\\"', e[f])

        # Rename some fields
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
                'alastnm', 'container-author', 'year']
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
        for e in self._e:
            for k in keys:
                zotkey = re.sub('#.*', '', k)
                if zotkey == self._e[e]['zotkey']:
                    ref += self._get_bib_ref(self._e[e], k)
        return ref

    def GetAttachment(self, zotkey):
        """ Tell Vim what attachment is associated with the citation key

            zotkey  (string): The Zotero key as it appears in the markdown document.
        """

        for k in self._e:
            if self._e[k]['zotkey'] == zotkey:
                if 'attachment' in self._e[k]:
                    return self._e[k]['attachment']
                return ["nOaTtAChMeNt"]
        return ["nOcItEkEy"]

    def GetRefData(self, zotkey):
        """ Return the key's dictionary.

            zotkey  (string): The Zotero key as it appears in the markdown document.
        """

        for k in self._e:
            if self._e[k]['zotkey'] == zotkey:
                return self._e[k]
        return "NoCiteKey"

    def GetNotes(self, key):
        zcopy = self._copy_zotero_data()
        conn = sqlite3.connect(zcopy)
        cur = conn.cursor()

        query = u"""
                SELECT items.itemID, items.key
                FROM items
                """
        cur.execute(query)

        key_id = ''
        for item_id, item_key in cur.fetchall():
            if item_key == key:
                key_id = item_id
                break

        cur.execute(u"SELECT itemID FROM deletedItems")
        zdel = []
        for item_id, in cur.fetchall():
            zdel.append(item_id)

        query = u"""
                SELECT itemNotes.itemID, itemNotes.parentItemID, itemNotes.note
                FROM itemNotes
                WHERE
                    itemNotes.parentItemID IS NOT NULL;
                """
        cur.execute(query)
        notes = ""
        for item_id, item_pId, item_note in cur.fetchall():
            if item_pId == key_id and not item_id in zdel:
                notes += item_note

        conn.close()

        if key_id in self._e:
            citekey = self._e[key_id]['citekey']
        else:
            citekey = ""
        if os.getenv('ZYearPageSep') is None:
            ypsep = ', p. '
        else:
            ypsep = os.getenv('ZYearPageSep')

        notes = re.sub('<div .*?>', '', notes, flags=re.M)
        notes = re.sub('</div>', '', notes, flags=re.M)
        notes = re.sub('<em>(.*?)</em>', '*\\1*', notes, flags=re.M)
        notes = re.sub('<strong>(.*?)</strong>', '**\\1**', notes, flags=re.M)
        notes = re.sub('<b>(.*?)</b>', '**\\1**', notes, flags=re.M)
        notes = re.sub('<i>(.*?)</i>', '*\\1*', notes, flags=re.M)
        notes = re.sub('<br>', '  \n', notes, flags=re.M)
        notes = re.sub('<br />', '  \n', notes, flags=re.M)
        notes = re.sub('<p>', '\n\n', notes, flags=re.M)
        notes = re.sub('</p>', '', notes, flags=re.M)
        notes = re.sub('\[', '\\[', notes, flags=re.M)
        notes = re.sub('\]', '\\]', notes, flags=re.M)
        notes = re.sub('_', '\\_', notes, flags=re.M)
        notes = re.sub('#', '\\#', notes, flags=re.M)
        notes = re.sub('&amp;', '&', notes, flags=re.M)
        notes = re.sub('<h1>(.*?)</h1>', '\n# \\1\n', notes, flags=re.M)
        notes = re.sub('<h2>(.*?)</h2>', '\n## \\1\n', notes, flags=re.M)
        notes = re.sub('<h3>(.*?)</h3>', '\n### \\1\n', notes, flags=re.M)
        notes = re.sub('<h4>(.*?)</h4>', '\n#### \\1\n', notes, flags=re.M)
        notes = re.sub('<h5>(.*?)</h5>', '\n###### \\1\n', notes, flags=re.M)
        if citekey == "":
            # More than two authors:
            notes = re.sub('\(<a href="zotero.*?">(.*?) et al ([0-9]*):([0-9]*)</a>\)', '[@' + key + '#\\1_etal_\\2' + ypsep + '\\3]', notes, flags=re.M)
            # Two authors:
            notes = re.sub('\(<a href="zotero.*?">(.*?) and (.*?) ([0-9]*):([0-9]*)</a>\)', '[@' + key + '#\\1_\\2_\\3' + ypsep + '\\4]', notes, flags=re.M)
            # One author:
            notes = re.sub('\(<a href="zotero.*?">(.*?) ([0-9]*):([0-9]*)</a>\)', '[@' + key + '#\\1_\\2' + ypsep + '\\3]', notes, flags=re.M)
            # None of the above...
            notes = re.sub('\(<a href="zotero.*?">(.*?)</a>\)', '[@' + key + '#\\1]', notes, flags=re.M)
        else:
            notes = re.sub('\(<a href="zotero.*?">(.*?) et al ([0-9]*):([0-9]*)</a>\)', '[@' + key + '#' + citekey + ypsep + '\\3]', notes, flags=re.M)
            notes = re.sub('\(<a href="zotero.*?">(.*?) and (.*?) ([0-9]*):([0-9]*)</a>\)', '[@' + key + '#' + citekey + ypsep + '\\4]', notes, flags=re.M)
            notes = re.sub('\(<a href="zotero.*?">(.*?) ([0-9]*):([0-9]*)</a>\)', '[@' + key + '#' + citekey + ypsep + '\\3]', notes, flags=re.M)
            notes = re.sub('\(<a href="zotero.*?">(.*?)</a>\)', '[@' + key + '#\\1]', notes, flags=re.M)
        notes = re.sub('<a title="(.*?)" href="(.*?)">(.*?)</a>', '[\\3](\\2 "\\1")', notes, flags=re.M)
        notes = re.sub('<a href="(.*?)">(.*?)</a>', '[\\2](\\1)', notes, flags=re.M)

        return notes + '\n'


    def Info(self):
        """ Return information that might be useful for users of ZoteroEntries """

        r = {'zotero.py': os.path.realpath(__file__),
             'zotero.sqlite': self._z,
             'tmpdir': self._tmpdir,
             'references found': len(self._e.keys()),
             'docs': str(self._d) + '\n',
             'citation template': self._cite,
             'banned words': self._bwords,
             'excluded fields': str(self._exclude),
            }
        return r
