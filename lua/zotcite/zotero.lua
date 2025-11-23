-- A lot of code was either adapted or plainly copied from citation_vim,
-- written by Rafael Schouten: https://github.com/rafaqz/citation.vim
-- Code and/or ideas were also adapted from zotxt, pypandoc, and pandocfilters.

-- To debug this code, create a /tmp/test.md file and do:
-- pandoc /tmp/test.md -F /full/path/to/zotcite/lua/zotcite/zotref.lua

-- We can't use the "vim" module because zotref will be called by external
-- tools. For the same reason, we can't use the "zotcite" module

local config = require("zotcite.config").get_config()

local cite_template
local banned_words = {}
local zcopy
local bbtcopy
local ztime
local exclude_fields = {}
local entry = {}
local collections = {}
local docs = {}

--- Create an object storing all references from ~/Zotero/zotero.sqlite

-- Conversion from zotero.sqlite to bib types
local _zbt = {
    artwork = "Misc",
    audioRecording = "Misc",
    blogPost = "Misc",
    book = "Book",
    bookSection = "InCollection",
    case = "Misc",
    computerProgram = "Book",
    conferencePaper = "InProceedings",
    dictionaryEntry = "InCollection",
    document = "TechReport",
    email = "Misc",
    encyclopediaArticle = "InCollection",
    film = "Misc",
    forumPost = "Misc",
    hearing = "Misc",
    instantMessage = "Misc",
    interview = "Misc",
    journalArticle = "Article",
    letter = "Misc",
    magazineArticle = "Article",
    newspaperArticle = "Article",
    note = "Misc",
    podcast = "Misc",
    presentation = "Misc",
    radioBroadcast = "Misc",
    statute = "Misc",
    thesis = "Thesis",
    tvBroadcast = "Misc",
    videoRecording = "Misc",
}

-- Conversion from zotero.sqlite to bib fields
-- It's incomplete and accuracy isn't guaranteed!
local _zbf = {
    abstractNote = "abstract",
    accessDate = "urldate",
    applicationNumber = "call-number",
    archiveLocation = "archive_location",
    artworkMedium = "medium",
    artworkSize = "dimensions",
    attachment = "file",
    audioFileType = "medium",
    blogTitle = "booktitle",
    bookTitle = "booktitle",
    callNumber = "call-number",
    code = "booktitle",
    codeNumber = "volume",
    codePages = "pages",
    codeVolume = "volume",
    conferenceName = "event",
    court = "authority",
    date = "issued",
    issueDate = "issued",
    dictionaryTitle = "booktitle",
    distributor = "publisher",
    encyclopediaTitle = "booktitle",
    extra = "note",
    filingDate = "submitted",
    forumTitle = "booktitle",
    genre = "type",
    history = "references",
    institution = "publisher",
    interviewMedium = "medium",
    issue = "number",
    issuingAuthority = "authority",
    legalStatus = "status",
    legislativeBody = "authority",
    libraryCatalog = "source",
    meetingName = "event",
    numPages = "pages",
    numberOfVolumes = "volume",
    place = "address",
    priorityNumbers = "issue",
    proceedingsTitle = "booktitle",
    programTitle = "booktitle",
    programmingLanguage = "type",
    publicationTitle = "booktitle",
    reporter = "booktitle",
    runningTime = "dimensions",
    seriesNumber = "number",
    session = "chapter-number",
    shortTitle = "shorttitle",
    system = "medium",
    thesisType = "type",
    university = "publisher",
    url = "URL",
    versionNumber = "version",
    websiteTitle = "booktitle",
    websiteType = "type",
}

local _creators = {
    "editor",
    "seriesEditor",
    "translator",
    "reviewedAuthor",
    "artist",
    "performer",
    "composer",
    "director",
    "podcaster",
    "cartographer",
    "programmer",
    "presenter",
    "interviewee",
    "interviewer",
    "recipient",
    "sponsor",
    "inventor",
}

local zwarn = require("zotcite").zwarn

local function expand_tilde(path)
    if path:match("^~(/.*)") then
        local home = os.getenv("HOME")
        if not home then home = os.getenv("USERPROFILE") end
        if home then return path:gsub("~", home, 1) end
    end
    return path
end

--- Check if a directory is writable
---@param dir string The directory path
---@return boolean
local function is_directory(dir)
    -- Can't use vim.uv.fs_access(dir, "rw") because it returns `true` for files
    local fname = dir .. "/Test_If_Dir_Is_Writable_By_Zotcite"
    local f = io.open(fname, "w")
    if f then
        f:close()
        os.remove(fname)
        return true
    end
    return false
end

-- Split a string 's' by a delimiter 'sep'
local function str_split(s, sep)
    local results = {}
    for part in string.gmatch(s, "([^" .. sep .. "]+)") do
        table.insert(results, part)
    end
    return results
end

local M = {}

--- Reads profile.ini to find prefs.js and then find the values of `data_dir`
--- and `attachment_dir`.
---@return string?, string?
local function get_zotero_prefs()
    local p1 = vim.env.APPDATA and vim.env.APPDATA .. "/Zotero/Zotero/profiles.ini"
        or expand_tilde("~/.zotero/zotero/profiles.ini")
    local zps = { p1, expand_tilde("~/Library/Application Support/Zotero/profiles.ini") }
    local zp = nil
    for _, p in pairs(zps) do
        if vim.uv.fs_access(p, "r") then
            zp = p
            break
        end
    end
    if not zp then
        zwarn("Could not find Zotero's `profiles.ini`", true)
        return
    end

    local adir
    local zsql
    local zotero_basedir = zp:match("^(.*)/.-")
    local lines = vim.fn.readfile(zp)
    for _, line in pairs(lines) do
        if line:find("Path=") == 1 then
            local zprofile = line:gsub("Path=", "")
            local zprefs = zotero_basedir .. "/" .. zprofile .. "/" .. "prefs.js"
            if vim.uv.fs_access(zprefs, "r") then
                local prefs = vim.fn.readfile(zprefs)
                for _, pref in pairs(prefs) do
                    if
                        pref:find("extensions.zotero.baseAttachmentPath")
                        and pref:find("extensions.zotero.baseAttachmentPath") > 0
                    then
                        adir = pref:match('.*", "(.*)".*\n')
                    end
                    if
                        pref:find("extensions.zotero.dataDir")
                        and pref:find("extensions.zotero.dataDir") > 0
                    then
                        local data_dir = pref:match('.*", "(.*)".*')
                        if vim.uv.fs_access(data_dir .. "/zotero.sqlite", "r") then
                            zsql = data_dir .. "/zotero.sqlite"
                        end
                    end
                end
            end
        end
    end
    return adir, zsql
end

---Define which Zotero collections each markdown document uses
---@param d string The name of the markdown document
---@param cl string[] The list of collections to be searched for citation keys when seeking references for the document 'd'.
function M.set_collections(d, cl)
    docs[d] = {}
    for _, c in pairs(cl) do
        if collections[c] then
            table.insert(docs[d], c)
        else
            zwarn('Collection "' .. c .. '" not found in Zotero database.')
        end
    end
end

--- Check modification time of file
---@param path string File path
---@return integer
local function getmtime(path)
    -- TODO: Check how frequently this function is called by different completion plugins
    -- local time_now = vim.uv.gettimeofday()
    -- vim.notify("time now: " .. tostring(time_now))
    local fd = vim.uv.fs_open(path, "r", tonumber("0444", 8))
    if fd then
        local fstat = vim.uv.fs_fstat(fd)
        vim.uv.fs_close(fd)
        if fstat then return fstat.mtime.sec end
    end
    return 0
end

local function copy_zotero_data()
    local zf = config.zotero_sqlite_path
    if not zf then return end
    ztime = getmtime(zf)
    zcopy = config.tmpdir .. "/copy_of_zotero.sqlite"
    local zcopy_time = getmtime(zcopy)

    -- Make a copy of zotero.sqlite to avoid locks
    if ztime > zcopy_time then vim.uv.fs_copyfile(zf, zcopy) end
    if config.key_type ~= "better-bibtex" then return end

    local bbt_f = zf:gsub("zotero%.sqlite$", "better-bibtex.sqlite")
    bbtcopy = config.tmpdir .. "/bbt.sqlite"
    local btime1 = getmtime(bbt_f)
    local btime2 = getmtime(bbtcopy)
    if btime1 > btime2 then vim.uv.fs_copyfile(bbt_f, bbtcopy) end
end

--- Run sqlite3 and get the output
---@param query string The SQL query
---@param sqlfile string | nil The path to the SQL data base
---@return table | nil
local function get_sql_data(query, sqlfile)
    local sf = sqlfile and sqlfile or zcopy
    local obj = vim.system({ "sqlite3", "-json", sf, query }, { text = true }):wait(3000)
    if obj.code ~= 0 then
        if obj.stderr then zwarn(obj.stderr) end
        return nil
    end
    if not obj.stdout then return nil end
    if obj.stdout == "" then return nil end
    return vim.json.decode(obj.stdout)
end

local function get_collections()
    collections = {}
    local query = "SELECT collections.collectionName, collectionItems.itemID "
        .. "FROM collections, collectionItems "
        .. "WHERE collections.collectionID = collectionItems.collectionID"

    local sql_data = get_sql_data(query)
    if not sql_data then return end
    for _, v in pairs(sql_data) do
        if not collections[v.collectionName] then collections[v.collectionName] = {} end
        table.insert(collections[v.collectionName], v.itemID)
    end
end

local function get_items_key_type()
    local query = "SELECT items.itemID, items.dateAdded, items.key, itemTypes.typeName"
        .. " FROM items, itemTypes"
        .. " WHERE items.itemTypeID = itemTypes.itemTypeID"

    local sql_data = get_sql_data(query)
    if not sql_data then return end
    entry = {}
    for _, v in pairs(sql_data) do
        if
            v.typeName ~= "attachment"
            and v.typeName ~= "annotation"
            and v.typeName ~= "note"
        then
            entry[v.itemID] =
                { zotkey = v.key, etype = v.typeName, added = v.dateAdded, alastnm = "" }
        end
    end
end

local function add_most_fields()
    local query = "SELECT items.itemID, fields.fieldName, itemDataValues.value"
        .. "  FROM items, fields, itemData, itemDataValues"
        .. "  WHERE items.itemID = itemData.itemID"
        .. "    and itemData.fieldID = fields.fieldID"
        .. "    and itemData.valueID = itemDataValues.valueID"
    local sql_data = get_sql_data(query)
    if not sql_data then return end
    for _, v in pairs(sql_data) do
        if entry[v.itemID] then entry[v.itemID][v.fieldName] = v.value end
    end
end

local function add_authors()
    local query = "SELECT items.itemID, creatorTypes.creatorType, creators.lastName, creators.firstName"
        .. "  FROM items, itemCreators, creators, creatorTypes"
        .. "  WHERE items.itemID = itemCreators.itemID"
        .. "    and itemCreators.creatorID = creators.creatorID"
        .. "    and itemCreators.creatorTypeID = creatorTypes.creatorTypeID"

    local sql_data = get_sql_data(query)
    if not sql_data then return end
    for _, v in pairs(sql_data) do
        if entry[v.itemID] ~= nil then
            if entry[v.itemID][v.creatorType] ~= nil then
                table.insert(entry[v.itemID][v.creatorType], { v.lastName, v.firstName })
            else
                entry[v.itemID][v.creatorType] = { { v.lastName, v.firstName } }
            end
            -- Special field for citation seeking
            if v.creatorType == "author" then
                entry[v.itemID].alastnm = entry[v.itemID].alastnm .. ", " .. v.lastName
            else
                local sought = { "author" }
                for _, c in pairs(_creators) do
                    if v.creatorType == c then
                        local flag = false
                        for _, s in pairs(sought) do
                            if entry[v.itemID][s] ~= nil then
                                flag = true
                                break
                            end
                        end
                        if not flag then
                            entry[v.itemID].alastnm = entry[v.itemID].alastnm
                                .. ", "
                                .. v.lastName
                        end
                    end
                    table.insert(sought, c)
                end
            end
        end
    end

    for _, v in pairs(entry) do
        v.alastnm = v.alastnm:gsub("^, ", "")
    end
end

local function get_year(e)
    local year = "????"
    if e.date then
        local y = e.date:match("^([0-9][0-9][0-9][0-9])")
        if y then
            year = y
        elseif e.issueDate then
            y = e.issueDate:match("^([0-9][0-9][0-9][0-9])")
            if y then year = y end
        end
    end
    return year
end

local function calculate_citekeys()
    local ptrn = "^(" .. table.concat(banned_words, " |") .. " )"
    for _, v in pairs(entry) do
        v.year = get_year(v)
        local titlew
        if v.title then
            ---@type string
            local title = v.title
            title = title:gsub(ptrn, "")
            title = title:lower()
            title = title:gsub("^[a-z] ", "")
            titlew = title:gsub("[ ,;:\\.!?].*", "")
        else
            v.title = ""
            titlew = ""
        end
        local lastname = "No_author"
        local lastnames = "No_author"
        local creators = { "author" }
        for _, x in pairs(_creators) do
            table.insert(creators, x)
        end
        local n = 0
        local lnms = {}
        for _, c in pairs(creators) do
            if v[c] then
                lastname = v[c][1][1]
                for _, ln in pairs(v[c]) do
                    table.insert(lnms, ln[1])
                    n = n + 1
                end
                break
            end
        end
        if n > 3 then
            lastnames = lnms[1] .. "-etal"
        else
            if n > 0 then lastnames = table.concat(lnms, "-") end
        end
        lastname = lastname:gsub("%W", "")
        titlew = titlew:gsub("%W", "")
        local key = cite_template
        key = key:gsub("%{author%}", lastname:lower(), 1)
        -- key = key:gsub("%{Author%}", lastname:title(), 1)
        key = key:gsub("%{Author%}", lastname, 1)
        key = key:gsub("%{authors%}", lastnames:lower(), 1)
        -- key = key:gsub("%{Authors%}", lastnames:title(), 1)
        key = key:gsub("%{Authors%}", lastnames, 1)
        key = key:gsub("%{year%}", v.year:gsub("^[0-9][0-9]", ""))
        key = key:gsub("%{Year%}", v.year)
        key = key:gsub("%{title%}", titlew:lower())
        -- key = key:gsub("{Title}", titlew:title(), 1)
        key = key:gsub("{Title}", titlew, 1)
        key = key:gsub(" ", "")
        key = key:gsub("'", "")
        key = key:gsub("’", "")
        v.citekey = key
    end
end

local function add_bbt_keys()
    local sql_data = get_sql_data("SELECT itemID, citationKey FROM citationkey", bbtcopy)
    if not sql_data then return end
    for _, v in pairs(sql_data) do
        local e = entry[v.itemID]
        if e then
            e.citekey = v.citationKey
            e.year = get_year(e)
        else
            zwarn("Entry with Better BibTeX itemID " .. v.itemID .. " not found")
        end
    end
end

local function get_sequence_string(n)
    local alphabet = "abcdefghijklmnopqrstuvwxyz"
    local s = ""
    while n > 0 do
        local remainder = (n - 1) % 26
        s = string.sub(alphabet, remainder + 1, remainder + 1) .. s
        n = math.floor((n - 1) / 26)
    end
    return s
end

local function add_citekeys()
    if config.key_type == "better-bibtex" then
        add_bbt_keys()
    else
        calculate_citekeys()
        if config.key_type == "template" then
            -- Fix duplicates
            for k1, v1 in pairs(entry) do
                local dup = { v1 }
                for k2, v2 in pairs(entry) do
                    if k1 ~= k2 and v1.citekey == v2.citekey then
                        table.insert(dup, v2)
                    end
                end
                if #dup > 1 then
                    table.sort(dup, function(a, b) return a.added > b.added end)
                    local i = 1
                    for _, v in pairs(dup) do
                        v.citekey = v.citekey .. get_sequence_string(i)
                        i = i + 1
                    end
                end
            end
        end
    end
end

local function delete_items()
    local sql_data = get_sql_data("SELECT itemID FROM deletedItems")
    if not sql_data then return end
    for _, v in pairs(sql_data) do
        entry[v.itemID] = nil
        for k, _ in pairs(collections) do
            for i, c in pairs(collections[k]) do
                if c == v.itemID then
                    table.remove(collections[k], i)
                    break
                end
            end
        end
    end
end

local function sanitize_markdown(s)
    s = s:gsub("%[", "\\[")
    s = s:gsub("%]", "\\]")
    s = s:gsub("@", "\\@")
    s = s:gsub("%*", "\\*")
    s = s:gsub("_", "\\_")
    return s
end

local function sanitize_latex(s)
    s = s:gsub("\\", "TeXtBacKsLasH")
    s = s:gsub("%%", "\\%%")
    s = s:gsub("&", "\\&")
    s = s:gsub("%$", "\\$")
    s = s:gsub("#", "\\#")
    s = s:gsub("_", "\\_")
    s = s:gsub("{", "\\{")
    s = s:gsub("}", "\\}")
    s = s:gsub("~", "\\textasciitilde{}")
    s = s:gsub("%^", "\\textasciicircum{}")
    s = s:gsub("TeXtBacKsLasH", "\\textbackslash{}")
    return s
end

local function sanitize(s, md)
    if md then
        return sanitize_markdown(s)
    else
        return sanitize_latex(s)
    end
end

---@param item table The Zotero item
---@param ktype string Type of citation key
local function get_bib_ref(item, ktype)
    local e = {}
    e = vim.tbl_extend("force", e, item)

    -- Fix the type
    if e["etype"] and _zbt and _zbt[e["etype"]] then
        e["etype"] = e["etype"]:gsub(e["etype"], _zbt[e["etype"]])
    end

    -- Escape quotes of all fields
    for f, v in pairs(e) do
        if type(v) == "string" then e[f] = v:gsub('"', '\\"') end
    end

    -- Rename some fields
    local ekeys = {}
    for k, _ in pairs(e) do
        table.insert(ekeys, k)
    end
    for _, f in pairs(ekeys) do
        if _zbf[f] then
            e[_zbf[f]] = e[f]
            e[f] = nil
        end
    end

    if e["etype"] == "Article" and e["booktitle"] then
        e["journal"] = e["booktitle"]
        e["booktitle"] = nil
    end
    if e["etype"] == "InCollection" and not e["editor"] then e["etype"] = "InBook" end

    for _, aa in pairs({
        "title",
        "journal",
        "booktitle",
        "journalAbbreviation",
        "address",
        "publisher",
    }) do
        if e[aa] then
            e[aa] = string.gsub(e[aa], '\\"', '"')
            e[aa] = string.gsub(e[aa], "\\\\", "\1")
            e[aa] = string.gsub(e[aa], "([&%%$#_%[%]{}])", "\\%1")
            e[aa] = string.gsub(e[aa], "\1", "{\\\\textbackslash}")
            e[aa] = string.gsub(e[aa], "<i>(.-)</i>", "\\\\textit{%1}")
            e[aa] = string.gsub(e[aa], "<b>(.-)</b>", "\\\\textbf{%1}")
            e[aa] = string.gsub(e[aa], "<sub>(.-)</sub>", "$_{\\\\textrm{%1}}$")
            e[aa] = string.gsub(e[aa], "<sup>(.-)</sup>", "$^{\\\\textrm{%1}}$")
            e[aa] = string.gsub(
                e[aa],
                '<span style="font%-variant:small%-caps;">(.-)</span>',
                "\\\\textsc{%1}"
            )
            e[aa] = string.gsub(e[aa], '<span class="nocase">(.-)</span>', "{%1}")
            e[aa] = string.gsub(e[aa], "\n", " ")
        end
    end

    local ekey = ktype == "zotero" and e.zotkey or e.citekey
    local ref = { "@" .. e["etype"] .. "{" .. ekey .. "," }
    for _, aa in pairs({
        "author",
        "editor",
        "contributor",
        "translator",
        "container-author",
    }) do
        if e[aa] then
            local names = {}
            for _, pair in pairs(e[aa]) do
                local last, first = pair[1], pair[2]
                table.insert(names, last .. ", " .. first)
            end
            table.insert(
                ref,
                "  " .. aa .. " = {" .. table.concat(names, " and ") .. "},"
            )
        end
    end
    if e["issued"] then
        local ds = e["issued"]
        ds = ds:gsub(" .*", "")
        local d = str_split(ds, "-")
        if d[1] ~= "0000" then
            table.insert(ref, "  year = {" .. e["year"] .. "},")
            if d[2] ~= "00" then table.insert(ref, "  month = {" .. d[2] .. "},") end
            if d[3] ~= "00" then table.insert(ref, "  day = {" .. d[3] .. "},") end
        end
    end
    if e["urldate"] then e["urldate"] = string.gsub(e["urldate"], " .*", "") end
    if e["pages"] then
        e["pages"] = string.gsub(e["pages"], "([0-9])-([0-9])", "%1--%2")
    end
    local dont = {
        "etype",
        "issued",
        "abstract",
        "collection",
        "author",
        "editor",
        "contributor",
        "translator",
        "alastnm",
        "container-author",
        "year",
    }
    for _, v in pairs(exclude_fields or {}) do
        table.insert(dont, v)
    end

    for f, val in pairs(e) do
        local skip = false
        for _, d in pairs(dont) do
            if f == d then
                skip = true
                break
            end
        end
        if not skip then
            local v = tostring(val):gsub("\n", " ")
            table.insert(ref, "  " .. f .. " = {" .. v .. "},")
        end
    end
    table.insert(ref, "}")
    table.insert(ref, "")
    return ref
end

--- Build the contents of a .bib file
---@param keys string[] List of Zotero keys
---@param ktype string Type of citation key
---@return table
local function get_bib(keys, ktype)
    local ref = {}
    for _, k in pairs(keys) do
        for _, e in pairs(entry) do
            local key = ktype == "zotero" and e.zotkey or e.citekey
            if k == key then ref[k] = get_bib_ref(e, ktype) end
        end
    end
    return ref
end

--- Build the contents of a .bib file
---@param zkeys string[] List of Zotero keys
---@param bibf string Name of bib file
---@param ktype string Type of citation key
---@param verbose boolean Whether to print debugging information or not
function M.update_bib(zkeys, bibf, ktype, verbose)
    local bib = {}

    local f = io.open(bibf, "r")
    if f then
        if verbose then zwarn('zotcite: updating "' .. tostring(bibf) .. '"\n') end
        local key = nil
        for line in f:lines() do
            if string.sub(line, 1, 1) == "@" then
                local clean_line = string.gsub(line, ",%s*$", "")
                key = string.gsub(clean_line, "^@.*{", "")
                bib[key] = {}
            end
            if key then table.insert(bib[key], line) end
        end
        f:close()
    else
        if verbose then zwarn('zotcite: writing "' .. tostring(bibf) .. '"\n') end
        bib = get_bib(zkeys, ktype)
    end

    -- Replace existing references and add new ones
    local newbib = get_bib(zkeys, ktype)
    for k, v in pairs(newbib) do
        bib[k] = v
    end

    f = io.open(bibf, "w")
    if f then
        for _, v in pairs(bib) do
            f:write(table.concat(v, "\n") .. "\n")
        end
        f:close()
    end
end

---Return list of attachments associated with the citation key
---@param key string The citation key
---@return table | nil, string
function M.get_attachment(key)
    local attachments = {}
    local field = config.key_type == "zotero" and "zotkey" or "citekey"
    for k, _ in pairs(entry) do
        if entry[k][field] == key then
            local query = "SELECT items.itemID, items.key, itemAttachments.path"
                .. " FROM items, itemAttachments"
                .. " WHERE items.itemID = itemAttachments.itemID and itemAttachments.parentItemID = '"
                .. k
                .. "'"
            local sql_data = get_sql_data(query)
            if not sql_data then return nil, "SQL query failed" end
            for _, v in pairs(sql_data) do
                if type(v.path) == "string" then
                    table.insert(attachments, v)
                else
                    zwarn("Path is not a string: " .. vim.inspect(v.path))
                end
            end

            if #attachments == 0 then return nil, "No attachments found" end
            return attachments, ""
        end
    end
    return nil, "Citation key not found"
end

function M.get_all_citations()
    -- Return a list of all [zotkey, citekey].
    local res = {}
    if require("zotcite.config").get_config().key_type == "zotero" then
        for _, e in pairs(entry) do
            res[e.zotkey] = e.citekey
        end
    else
        for k, e in pairs(entry) do
            if e.citekey and e.zotkey then
                res[e.citekey] = e.zotkey
            else
                zwarn("Missing citation key for itemID " .. tostring(k))
            end
        end
    end
    return res
end

local get_ref_data_template = function(citekey)
    for _, v in pairs(entry) do
        if v.citekey == citekey then return v end
    end
    return nil
end

local get_ref_data_zotkey = function(zotkey)
    for _, v in pairs(entry) do
        if v.zotkey == zotkey then return v end
    end
    return nil
end

function M.get_ref_data(key)
    if config.key_type == "zotero" then
        return get_ref_data_zotkey(key)
    else
        return get_ref_data_template(key)
    end
end

local function get_ypsep(md)
    local ypsep = config.year_page_sep
    if not ypsep then
        if md then
            ypsep = ", p. "
        else
            ypsep = "p.~"
        end
    end
    return ypsep
end

local get_key_id = function(zotkey)
    local key_id = nil
    for k, v in pairs(entry) do
        if v.zotkey == zotkey then
            key_id = k
            break
        end
    end
    return key_id
end

-- Return user annotations made using Zotero's PDF viewer.
function M.get_annotations(key, offset, md)
    if not config.zotero_sqlite_path then return end
    copy_zotero_data()

    local key_id = get_key_id(key)
    if not key_id then return end

    local query = "SELECT itemAttachments.itemID, itemAttachments.parentItemID,"
        .. "\n  itemAnnotations.parentItemID, itemAnnotations.type,"
        .. "\n  itemAnnotations.position, itemAnnotations.pageLabel,"
        .. "\n  itemAnnotations.authorName, itemAnnotations.text,"
        .. "\n  itemAnnotations.comment"
        .. "\nFROM itemAttachments, itemAnnotations"
        .. "\nWHERE itemAttachments.parentItemID = "
        .. key_id
        .. " and itemAnnotations.parentItemID = itemAttachments.ItemID"
    local sql_data = get_sql_data(query)
    if not sql_data then return end

    local ckey = config.key_type == "zotero" and key or entry[key_id].citekey
    -- Year-page separator
    local s = get_ypsep(md)

    local notes = {}
    for _, v in pairs(sql_data) do
        local position = vim.json.decode(v.position)
        local page
        if v.pageLabel ~= vim.NIL then
            page = v.pageLabel
        else
            page = tostring(position.pageIndex + offset)
        end
        table.insert(notes, {
            p = page,
            pos_page = position.pageIndex,
            pos_x = position.rects[1][1],
            pos_y = position.rects[1][2],
            c = v.comment ~= vim.NIL and v.comment,
            t = v.text ~= vim.NIL and v.text,
            type = v.type,
        })
    end
    table.sort(notes, function(a, b)
        if a.pos_page ~= b.pos_page then
            return a.pos_page < b.pos_page
        else
            return a.pos_y > b.pos_y
        end
    end)
    local lines = {}
    for _, v in pairs(notes) do
        if v.c then
            local txt = sanitize(v.c, md)
            if md then
                txt = string.format("%s [comment on @%s%s%s]", txt, ckey, s, v.p)
            else
                txt =
                    string.format("%s [comment on \\citet[%s%s]{%s}]", txt, s, v.p, ckey)
            end
            table.insert(lines, txt)
            table.insert(lines, "")
        end
        if v.t then
            local txt = sanitize(v.t, md)
            if md then
                txt = string.format("> %s [@%s%s%s]", txt, ckey, s, v.p)
                table.insert(lines, txt)
            else
                table.insert(lines, "\\begin{quote}")
                txt = string.format("%s \\cite[%s%s]{%s}", txt, s, v.p, ckey)
                table.insert(lines, txt)
                table.insert(lines, "\\end{quote}")
            end
            table.insert(lines, "")
        end
    end
    return lines
end

local notes_to_tex = function(notes)
    -- Year-page separator
    local ypsep = get_ypsep(true)

    notes = notes:gsub("<h1>(.-)</h1>", "\\section{%1}\n")
    notes = notes:gsub("<h2>(.-)</h2>", "\\subsection{%1}\n")
    notes = notes:gsub("<h3>(.-)</h3>", "\\subsubsection{%1}\n")
    notes = notes:gsub("<h4>(.-)</h4>", "\\subsubsection{%1}\n")
    notes = notes:gsub("<h5>(.-)</h5>", "\\subsubsection{%1}\n")
    notes = notes:gsub("<strong>(.-)</strong>", "\\textbf{%1}")
    notes = notes:gsub("<em>(.-)</em>", "\\em{%1}")
    notes = notes:gsub(
        '<span style="text%-decoration: line%-through">(.-)</span>',
        "\\strikethrough{%1}"
    )
    notes = notes:gsub(' rel="noopener noreferrer nofollow"', "")
    notes = notes:gsub('<a href="(.-)">(.-)</a>', "\\href{%1}{%2}")
    notes = notes:gsub('%(<span class="citation%-item">.-</span>%)', "")
    notes = notes:gsub(
        '<span class="citation" data%-citation=".-items%%2F(.-)%%.-locator%%22%%3A%%22(.-)%%22.-">.-</span>',
        "\\cite[" .. ypsep .. "%2]{%1}"
    )
    notes = notes:gsub(
        '<span class="citation" data%-citation=".-items%%2F(.-)%%.-">',
        "\\cite{%1}"
    )
    notes = notes:gsub("<li>%s*(.-)%s*</li>", "\n  \\item %1")
    notes = notes:gsub("<ul>(.-)</ul>", "\n\\begin{itemize}%1\\end{itemize}\n")
    notes = notes:gsub("<ol>(.-)</ol>", "\n\\begin{enumerate}%1\\end{enumerate}\n")
    notes = notes:gsub(
        "<blockquote>%s*(.-)%s*</blockquote>",
        "\n\\begin{quote}\n%1\n\\end{quote}\n"
    )
    notes = notes:gsub('<pre class="math">(.-)</pre>', "\n%1\n")
    notes = notes:gsub("<pre>(.-)</pre>", "\n\\begin{verbatim}\n%1\nend{verbatim}\n")
    notes = notes:gsub("<br/>", "\\linebreak\n")
    notes = notes:gsub("<p>(.-)</p>", "%1\n\n")
    notes = notes:gsub(' class="highlight" data%-annotation=".-"(.-)', "")
    notes = notes:gsub("<div .->", "")
    notes = notes:gsub("</div>", "")
    notes = notes:gsub("<span>", "")
    notes = notes:gsub("</span>", "")
    notes = notes:gsub("\n\n\n", "\n\n")
    return notes .. "\n"
end

local notes_to_md = function(notes)
    -- Year-page separator
    local ypsep = get_ypsep(true)

    notes = notes:gsub("<h1>(.-)</h1>", "# %1\n")
    notes = notes:gsub("<h2>(.-)</h2>", "## %1\n")
    notes = notes:gsub("<h3>(.-)</h3>", "### %1\n")
    notes = notes:gsub("<h4>(.-)</h4>", "#### %1\n")
    notes = notes:gsub("<h5>(.-)</h5>", "##### %1\n")
    notes = notes:gsub("<strong>(.-)</strong>", "**%1**")
    notes = notes:gsub("<em>(.-)</em>", "*%1*")
    notes =
        notes:gsub('<span style="text%-decoration: line%-through">(.-)</span>', "~~%1~~")
    notes = notes:gsub(' rel="noopener noreferrer nofollow"', "")
    notes = notes:gsub('<a href="(.-)">(.-)</a>', "[%2](%1)")
    notes = notes:gsub('%(<span class="citation%-item">.-</span>%)', "")
    notes = notes:gsub(
        '<span class="citation" data%-citation=".-items%%2F(.-)%%.-locator%%22%%3A%%22(.-)%%22.-">.-</span>',
        "[@%1" .. ypsep .. "%2]"
    )
    notes =
        notes:gsub('<span class="citation" data%-citation=".-items%%2F(.-)%%.-">', "@%1")
    notes = notes:gsub("<li>%s*(.-)%s*</li>", "\n  - %1")
    notes = notes:gsub("<ul>(.-)</ul>", "\n%1\n")
    notes = notes:gsub("<ol>(.-)</ol>", "\n%1\n")
    notes = notes:gsub("<blockquote>%s*(.-)%s*</blockquote>", "\n> %1\n")
    notes = notes:gsub('<pre class="math">(.-)</pre>', "\n%1\n")
    notes = notes:gsub("<pre>(.-)</pre>", "\n```\n%1\n```\n")
    notes = notes:gsub("<br/>", "\n\n")
    notes = notes:gsub("<p>(.-)</p>", "%1\n\n")
    notes = notes:gsub(' class="highlight" data%-annotation=".-"(.-)', "")
    notes = notes:gsub("<div .->", "")
    notes = notes:gsub("</div>", "")
    notes = notes:gsub("<span>", "")
    notes = notes:gsub("</span>", "")
    notes = notes:gsub("\n\n\n", "\n\n")
    return notes .. "\n"
end

local notes_to_typ = function(notes)
    -- Year-page separator
    local ypsep = get_ypsep(true)

    notes = notes:gsub("<h1>(.-)</h1>", "= %1\n")
    notes = notes:gsub("<h2>(.-)</h2>", "== %1\n")
    notes = notes:gsub("<h3>(.-)</h3>", "=== %1\n")
    notes = notes:gsub("<h4>(.-)</h4>", "==== %1\n")
    notes = notes:gsub("<h5>(.-)</h5>", "===== %1\n")
    notes = notes:gsub("<strong>(.-)</strong>", "*%1*")
    notes = notes:gsub("<em>(.-)</em>", "_%1_")
    notes =
        notes:gsub('<span style="text%-decoration: line%-through">(.-)</span>', "~~%1~~")
    notes = notes:gsub(' rel="noopener noreferrer nofollow"', "")
    notes = notes:gsub('<a href="(.-)">(.-)</a>', '#link("%1")[%2]')
    notes = notes:gsub('%(<span class="citation%-item">.-</span>%)', "")
    notes = notes:gsub(
        '<span class="citation" data%-citation=".-items%%2F(.-)%%.-locator%%22%%3A%%22(.-)%%22.-">.-</span>',
        '#cite(<%1>, supplement: "' .. ypsep .. '%2", form: "normal")'
    )
    notes =
        notes:gsub('<span class="citation" data%-citation=".-items%%2F(.-)%%.-">', "@%1")
    notes = notes:gsub("<li>%s*(.-)%s*</li>", "\n  - %1")
    notes = notes:gsub("<ul>(.-)</ul>", "\n%1\n")
    notes = notes:gsub("<ol>(.-)</ol>", "\n%1\n")
    notes = notes:gsub("<blockquote>%s*(.-)%s*</blockquote>", "\n#quote[%1]\n")
    notes = notes:gsub('<pre class="math">(.-)</pre>', "\n%1\n")
    notes = notes:gsub("<pre>(.-)</pre>", "\n```\n%1\n```\n")
    notes = notes:gsub("<br/>", "\n\n")
    notes = notes:gsub("<p>(.-)</p>", "%1\n\n")
    notes = notes:gsub(' class="highlight" data%-annotation=".-"(.-)', "")
    notes = notes:gsub("<div .->", "")
    notes = notes:gsub("</div>", "")
    notes = notes:gsub("<span>", "")
    notes = notes:gsub("</span>", "")
    notes = notes:gsub("\n\n\n", "\n\n")
    return notes .. "\n"
end

-- Return user notes from a reference.
---@param key string The Zotero key
---@param lang string The document language
---@return string | nil
function M.get_notes(key, lang)
    if not config.zotero_sqlite_path then return end
    copy_zotero_data()

    local key_id = get_key_id(key)
    if not key_id then return end

    local query = "SELECT parentItemID, note FROM itemNotes WHERE parentItemID = "
        .. tostring(key_id)
    local sql_data = get_sql_data(query)
    if not sql_data then return end

    local notes = ""
    for _, v in pairs(sql_data) do
        notes = notes .. v.note
    end
    if notes == "" then return nil end

    notes = sanitize(notes, lang)
    if lang == "typst" then
        notes = notes_to_typ(notes)
    elseif lang == "latex" then
        notes = notes_to_tex(notes)
    else
        notes = notes_to_md(notes)
    end
    return notes
end

--- Return information useful for debugging the application
---@return table
function M.info()
    local ntypes = {}
    local n = 0
    for _, v in pairs(entry) do
        n = n + 1
        if ntypes[v.etype] then
            ntypes[v.etype] = ntypes[v.etype] + 1
        else
            ntypes[v.etype] = 1
        end
    end

    local r = {
        ["attach_dir"] = config.attach_dir,
        ["zotero.sqlite"] = config.zotero_sqlite_path,
        ["tmpdir"] = config.tmpdir,
        ["docs"] = docs,
        ["citation template"] = cite_template,
        ["banned words"] = table.concat(banned_words, ", "),
        ["excluded fields"] = table.concat(exclude_fields, ", "),
        ["n refs"] = n,
        ["types"] = ntypes,
    }
    return r
end

local function load_zotero_data()
    if not config.zotero_sqlite_path then return end
    copy_zotero_data()

    get_collections()
    get_items_key_type()
    delete_items()
    add_most_fields()
    add_authors()
    add_citekeys()
end

--- Find citation key and return list of completions
---@param ptrn string Search pattern
---@param d string Buffer name
---@return table
function M.get_match(ptrn, d)
    if getmtime(config.zotero_sqlite_path) > ztime then load_zotero_data() end

    local keys = {}
    if docs[d] then
        for _, c in pairs(docs[d]) do
            for _, v in pairs(collections[c]) do
                table.insert(keys, v)
            end
        end
    end
    if #keys == 0 then
        for k, _ in pairs(entry) do
            table.insert(keys, k)
        end
    end

    -- priority level
    local p1, p2, p3, p4, p5, p6 = {}, {}, {}, {}, {}, {}

    ptrn = ptrn:lower()
    for _, v in ipairs(keys) do
        local e = entry[v]
        if e.citekey:lower():find(ptrn) == 1 then
            table.insert(p1, e)
        elseif e.alastnm and e.alastnm[1] and e.alastnm[1][1]:lower():find(ptrn) == 1 then
            table.insert(p2, e)
        elseif e.title:lower():find(ptrn) == 1 then
            table.insert(p3, e)
        elseif e.citekey:lower():find(ptrn) and e.citekey:lower():find(ptrn) > 1 then
            table.insert(p4, e)
        elseif
            e.alastnm
            and e.alastnm[1]
            and e.alastnm[1][1]:lower():find(ptrn)
            and e.alastnm[1][1]:lower():find(ptrn) > 1
        then
            table.insert(p5, e)
        elseif e.title:lower():find(ptrn) and e.title:lower():find(ptrn) > 1 then
            table.insert(p6, e)
        end
    end

    local resp = {}
    for _, v in pairs(p1) do
        table.insert(resp, v)
    end
    for _, v in pairs(p2) do
        table.insert(resp, v)
    end
    for _, v in pairs(p3) do
        table.insert(resp, v)
    end
    for _, v in pairs(p4) do
        table.insert(resp, v)
    end
    for _, v in pairs(p5) do
        table.insert(resp, v)
    end
    for _, v in pairs(p6) do
        table.insert(resp, v)
    end
    return resp
end

--- Get Zotero data
---@return boolean
function M.init()
    -- Template for citation keys
    cite_template = config.citation_template
    if not cite_template then cite_template = "{Authors}-{Year}" end

    -- Title words to be ignored
    local bw = config.banned_words
    if bw then
        banned_words = str_split(bw, " ")
    else
        banned_words =
            { "a", "an", "the", "some", "from", "on", "in", "to", "of", "do", "with" }
    end

    -- Path to zotero.sqlite
    if config.zotero_sqlite_path then
        if not vim.uv.fs_access(config.zotero_sqlite_path, "r") then
            local msg = 'Please, check if the config option `zotero_sqlite_path` is set correctly: "'
                .. config.zotero_sqlite_path
                .. '" not found.'
            zwarn(msg)
            return false
        end
    end

    -- Path to attachments directory
    if config.attach_dir and not is_directory(config.attach_dir) then
        local msg = "Please, fix the value `attach_dir` in your config. The directory "
            .. config.attach_dir
            .. " is not writable."
        zwarn(msg)
        return false
    end

    if not config.zotero_sqlite_path then
        local adir, zdir = get_zotero_prefs()
        if adir and not config.attach_dir then config.attach_dir = adir end
        if zdir then
            config.zotero_sqlite_path = zdir
        else
            return false
        end
    end

    -- Temporary directory
    if not config.tmpdir then
        if os.getenv("XDG_CACHE_HOME") then
            config.tmpdir = os.getenv("XDG_CACHE_HOME") .. "/zotcite"
        elseif os.getenv("APPDATA") then
            config.tmpdir = os.getenv("APPDATA") .. "/zotcite"
        elseif is_directory(expand_tilde("~/.cache")) then
            config.tmpdir = expand_tilde("~/.cache/zotcite")
        elseif is_directory(expand_tilde("~/Library/Caches")) then
            config.tmpdir = expand_tilde("~/Library/Caches/zotcite")
        else
            config.tmpdir = "/tmp/.zotcite"
        end
    end

    if not is_directory(config.tmpdir) then
        if vim.fn.mkdir(config.tmpdir, "p", "0o700") == 0 then
            zwarn("Error creating directory '" .. config.tmpdir .. "'")
            return false
        end
        if not is_directory(config.tmpdir) then
            zwarn(
                'Please, either set or fix the value of `tmpdir` in your zotcite config: "'
                    .. config.tmpdir
                    .. '" is not writable.'
            )
            return false
        end
    end

    -- Fields that should not be added to the bib entries:
    local zexcl = config.exclude_fields
    if not zexcl then
        exclude_fields = {}
    else
        exclude_fields = str_split(zexcl, " ")
    end

    load_zotero_data()

    return true
end

return M
