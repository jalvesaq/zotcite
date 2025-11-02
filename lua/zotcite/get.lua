local config = require("zotcite.config").get_config()
local zwarn = require("zotcite").zwarn
local seek = require("zotcite.seek")
local zotero = require("zotcite.zotero")

local offset = "0"
local pdfnote_data = {}
local sel_list = {}

local citation = {
    start_col = 0,
    end_col = 0,
}

local M = {}

local TranslateZPath = function(strg)
    local fpath = strg

    if
        config.open_in_zotero
        and (string.lower(strg):find("%.pdf$") or string.lower(strg):find("%.html$"))
    then
        local id = fpath:gsub(":.*", "")
        return "zotero://open-pdf/library/items/" .. id
    end

    if strg:find(":attachments:") then
        -- The user has set Edit / Preferences / Files and Folders / Base directory for linked attachments
        if config.attach_dir == "" then
            zwarn("Attachments dir is not defined")
        else
            fpath = strg:gsub(".*:attachments:", "/" .. config.attach_dir .. "/")
        end
    elseif strg:find(":/") then
        -- Absolute file path
        fpath = strg:gsub(".*:/", "/")
    elseif strg:find(":storage:") then
        -- Default path
        fpath = config.data_dir .. strg:gsub("(.*):storage:", "/storage/%1/")
    end
    if vim.fn.filereadable(fpath) == 0 then
        zwarn('Could not find "' .. fpath .. '"')
        fpath = ""
    end
    return fpath
end

M.PDFPath = function(zotkey, cb)
    local repl = zotero.get_attachment(zotkey)
    if #repl == 0 then
        zwarn("Got empty list")
        return
    end
    if repl[1] == "nOaTtAChMeNt" then
        zwarn("Attachment not found")
    elseif repl[1] == "nOcItEkEy" then
        zwarn("Citation key not found")
    else
        local fpaths = {}
        local item = ""
        for _, v in pairs(repl) do
            item = TranslateZPath(v):gsub(".*storage:", "")
            table.insert(fpaths, item)
        end
        if #repl == 1 then
            return fpaths[1]
        else
            local idx = 1
            local items = {}
            sel_list = {}
            for _, v in pairs(fpaths) do
                item = v:gsub(".*/", "")
                item = vim.fn.slice(item, 0, 60)
                table.insert(items, item)
                table.insert(sel_list, v)
                idx = idx + 1
            end
            vim.schedule(function() vim.ui.select(items, {}, cb) end)
        end
    end
end

local is_valid_char = function(c)
    return (c >= "0" and c <= "9")
        or (c >= "A" and c <= "z")
        or (c >= "a" and c <= "z")
        or c:byte(1, 1) > 127
end

local citation_key_vt = function(line, pos)
    pos = pos + 1
    if line:sub(pos, pos) == "<" then
        pos = pos + 1
    elseif line:sub(pos, pos) == ">" then
        pos = pos - 1
    end
    local i = pos
    local j = pos
    while i > 0 and is_valid_char(line:sub(i, i)) do
        i = i - 1
    end
    while j <= #line and is_valid_char(line:sub(j, j)) do
        j = j + 1
    end
    local key = line:sub(i + 1, j - 1)
    if #key == 8 then return key end
    return ""
end

M.citation_key = function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
    local pos = vim.api.nvim_win_get_cursor(0)[2]
    return citation_key_vt(line, pos)
end

M.yaml_ref = function()
    local wrd = M.citation_key()
    if wrd ~= "" then
        local repl = zotero.get_yaml_refs(wrd)
        repl = repl:gsub("^references:[\n\r]*", "")
        if repl == "" then
            zwarn("Citation key not found")
        else
            vim.schedule(function() vim.api.nvim_echo({ { repl } }, false, {}) end)
        end
    end
end

M.reference_data = function(btype)
    local wrd = M.citation_key()
    if wrd ~= "" then
        local repl = zotero.get_ref_data(wrd)
        if type(repl) ~= "table" then
            zwarn("Citation key not found")
            return
        end
        local info = {}
        if btype == "raw" then
            for k, v in pairs(repl) do
                table.insert(info, { k, "Title" })
                table.insert(info, { ": " .. vim.inspect(v):gsub("\n$", "") .. "\n" })
            end
        else
            if repl.alastnm then
                table.insert(info, { repl.alastnm .. " ", "Identifier" })
            end
            if repl.year then table.insert(info, { repl.year .. " ", "Number" }) end
            if repl.title then table.insert(info, { repl.title, "Title" }) end
        end
        vim.schedule(function() vim.api.nvim_echo(info, false, {}) end)
    end
end

local finish_citation = function(ref)
    if not ref then return end
    local rownr = vim.api.nvim_win_get_cursor(0)[1] - 1
    local cite = ref.value.key
    if not (vim.bo.filetype == "tex" or vim.bo.filetype == "rnoweb") then
        cite = "@" .. cite
    end
    vim.api.nvim_buf_set_text(
        0,
        rownr,
        citation.start_col,
        rownr,
        citation.end_col,
        { cite }
    )
    local colnr = citation.start_col + #cite
    vim.api.nvim_win_set_cursor(0, { rownr + 1, colnr })
    vim.api.nvim_feedkeys("a", "n", false)
    vim.schedule(require("zotcite.hl").citations)
end

M.citation = function()
    local argmt = ""
    local line = vim.api.nvim_get_current_line()
    local last = vim.api.nvim_win_get_cursor(0)[2]
    citation.start_col = last
    citation.end_col = last
    local c = line:sub(last, last):lower()
    if (c >= "a" and c <= "z") or c > "\127" then
        local first = last - 1
        while first > 0 and ((c >= "a" and c <= "z") or c > "\127") do
            first = first - 1
            c = line:sub(first, first):lower()
        end
        argmt = line:sub(first + 1, last):lower()
        citation.start_col = first
    end
    seek.refs(argmt, finish_citation)
end

M.abstract = function()
    local wrd = M.citation_key()
    if wrd ~= "" then
        local repl = zotero.get_ref_data(wrd)
        if type(repl) ~= "table" then
            zwarn("Citation key not found")
            return
        end
        if repl.abstractNote then
            vim.api.nvim_put({ repl.abstractNote }, "l", true, true)
        else
            zwarn("No abstract found associated with article")
        end
    end
end

local get_annotations = function(sel)
    local is_markdown = not vim.tbl_contains({ "tex", "rnoweb" }, vim.o.filetype)
    local key = sel.value.key
    local repl = zotero.get_annotations(key, offset, is_markdown)
    if not repl then zwarn("No annotation found.") end
    return repl
end

local finish_annotations = function(sel)
    if not sel then return end

    local repl = get_annotations(sel)
    if not repl then return end

    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, lnum, lnum, true, repl)
    require("zotcite.hl").citations()
end

local finish_annotations_selection = function(sel)
    if not sel then return end
    local raw_annotations = get_annotations(sel)
    if raw_annotations then
        local grouped_annotations = {}
        local current_group = {}
        local last_was_quote = false

        for _, line in ipairs(raw_annotations) do
            if line:sub(1, 1) == ">" then
                if #current_group > 0 and not last_was_quote then
                    table.insert(current_group, line)
                    table.insert(grouped_annotations, table.concat(current_group, "\n"))
                    current_group = {}
                else
                    if #current_group > 0 then
                        table.insert(
                            grouped_annotations,
                            table.concat(current_group, "\n")
                        )
                        current_group = {}
                    end
                    table.insert(current_group, line)
                end
                last_was_quote = true
            else
                if last_was_quote and #current_group > 0 then
                    table.insert(grouped_annotations, table.concat(current_group, "\n"))
                    current_group = {}
                end
                table.insert(current_group, line)
                last_was_quote = false
            end
        end

        if #current_group > 0 then
            table.insert(grouped_annotations, table.concat(current_group, "\n"))
        end

        local selected_indices = {}
        local function select_annotation()
            local opts = {}
            local w = vim.o.columns - 10
            if w > 140 then w = 140 end
            for i, annotation in ipairs(grouped_annotations) do
                if not selected_indices[i] then
                    table.insert(opts, i .. ": " .. annotation:sub(1, w)) -- Show first chars
                end
            end

            if #opts == 0 then
                if #selected_indices > 0 then
                    local sel_annot = {}
                    for index in pairs(selected_indices) do
                        table.insert(sel_annot, grouped_annotations[index])
                    end
                    local lnum = vim.api.nvim_win_get_cursor(0)[1]
                    local txt = table.concat(sel_annot, "\n\n")
                    local lines = vim.split(txt, "\n")
                    vim.api.nvim_buf_set_lines(0, lnum, lnum, true, lines)
                    require("zotcite.hl").citations()
                end
                return
            end

            vim.ui.select(
                opts,
                { prompt = "Select annotation (or cancel to finish)" },
                function(choice)
                    if choice then
                        local index = tonumber(vim.split(choice, ":")[1])
                        if index then
                            selected_indices[index] = true
                            select_annotation() -- Ask for the next selection
                        end
                    else
                        if #selected_indices > 0 then
                            local annot = {}
                            for index in pairs(selected_indices) do
                                table.insert(annot, grouped_annotations[index])
                            end
                            local lnum = vim.api.nvim_win_get_cursor(0)[1]
                            vim.api.nvim_buf_set_lines(
                                0,
                                lnum,
                                lnum,
                                true,
                                vim.split(table.concat(annot, "\n\n"), "\n")
                            )
                            require("zotcite.hl").citations()
                        end
                    end
                end
            )
        end

        select_annotation()
    end
end

M.annotations = function(ko, use_selection)
    local argmt
    if ko:find(" ") then
        ko = vim.fn.split(ko)
        argmt = ko[1]
        offset = ko[2]
    else
        argmt = ko
        offset = "0"
    end
    if use_selection then
        seek.refs(argmt, finish_annotations_selection)
    else
        seek.refs(argmt, finish_annotations)
    end
end

local finish_note = function(sel)
    local key = sel.value.key
    local is_markdown = not vim.tbl_contains({ "tex", "rnoweb" }, vim.o.filetype)
    local repl = zotero.get_notes(key, is_markdown)
    if not repl then
        zwarn("No note found.")
    else
        local lines = vim.fn.split(repl, "\n")
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        vim.api.nvim_buf_set_lines(0, lnum, lnum, true, lines)
        require("zotcite.hl").citations()
    end
end

M.note = function(key) seek.refs(key, finish_note) end

local finish_pdfnote_2 = function(_, idx)
    local fpath = sel_list[idx]

    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local key = pdfnote_data.citekey
    local p = pdfnote_data.pg
    if vim.fn.filereadable(fpath) == 0 then
        zwarn('File not readable: "' .. fpath .. '"')
        return
    end

    -- Determine which PDF extractor to use
    local pdf_extractor = config.pdf_extractor or "pdfnotes.py"

    local notes = vim.system(
        { config.python_path, config.zotcite_home .. "/" .. pdf_extractor, fpath, key, p },
        { text = true }
    ):wait()
    if notes.code == 0 then
        local lines = vim.fn.split(notes.stdout, "\n")
        vim.api.nvim_buf_set_lines(0, lnum, lnum, true, lines)
        require("zotcite.hl").citations()
    elseif notes.code == 33 then
        zwarn('Failed to load "' .. fpath .. '" as a valid PDF document.')
    elseif notes.code == 34 then
        zwarn("No annotations found.")
    else
        zwarn(notes.stderr)
    end
end

local finish_pdfnote = function(sel)
    local zotkey = sel.value.key
    local repl = zotero.get_ref_data(zotkey)
    if type(repl) ~= "table" then
        zwarn("Citation key not found")
        return
    end
    local citekey
    citekey = "@" .. zotkey
    local pg = "1"
    if repl.pages and repl.pages:find("[0-9]-") then pg = repl.pages end
    pdfnote_data = { citekey = citekey, pg = pg }

    local apath = M.PDFPath(zotkey, finish_pdfnote_2)
    if type(apath) == "string" then
        sel_list = { apath }
        finish_pdfnote_2(nil, 1)
    end
end

M.PDFNote = function(key) seek.refs(key, finish_pdfnote) end

--- Strip string from empty spaces and quotes
---@param line string The string to be stripped
---@return string
local get_yaml_string = function(line)
    local str
    if line:find("^'.*'$") then
        str = line:match("^%s*'(.-)'%s*$")
    elseif line:find('^%s*".*"%s*$') then
        str = line:match('^%s*"(.-)"%s*$')
    else
        str = line:match("^%s*(.-)%s*$")
    end
    return str
end

--- Get the value of a YAML field
---@param field string Field name
---@param bn integer Buffer number
---@return string | string[] | nil
M.yaml_field = function(field, bn)
    if vim.tbl_contains({ "tex", "rnoweb" }, vim.bo.filetype) then return nil end
    local line1 = vim.api.nvim_buf_get_lines(bn, 0, 1, true)[1]
    if line1 ~= "---" then return end

    local lines = vim.api.nvim_buf_get_lines(bn, 0, -1, true)
    local nlines = #lines
    local i = 2
    local value
    while i < nlines do
        if lines[i] == "---" then break end
        if lines[i]:find(field .. ":") then
            if lines[i]:find(field .. ":%s*$") then
                -- multiline list
                value = {}
                i = i + 1
                while lines[i]:find("^%s*%-") do
                    if lines[i] == "---" then break end
                    local line = lines[i]:match("^%s*%-%s*(.-)%s*$")
                    table.insert(value, get_yaml_string(line))
                    i = i + 1
                end
            elseif lines[i]:find(field .. ":%s%[.*%]%s*$") then
                -- bracketed list in a single line
                value = vim.split(lines[i]:match("^" .. field .. ":%s*%[(.-)%]%s*$"), ",")
                for k, v in pairs(value) do
                    value[k] = get_yaml_string(v)
                end
            else
                -- string
                value = lines[i]:match("^%s*" .. field .. ":%s*(.-)%s*$")
                value = get_yaml_string(value)
            end
            return value
        end
        i = i + 1
    end
    return nil
end

--- Get collection names from buffer and set them in zotero.lua
---@param bn integer Buffer number
M.collection_name = function(bn)
    local newc = M.yaml_field("collection", bn)
    if not newc then return end

    if type(newc) == "string" then newc = { newc } end
    zotero.set_collections(vim.api.nvim_buf_get_name(0), newc)
end

--- Insert echo lines into table
---@param info table The table with echo lines
---@param ttl string Section title
---@param lines string[] Lines to insert
local function insert_info(info, ttl, lines)
    table.insert(info, { ttl .. "\n", "Statement" })
    for k, v in pairs(lines) do
        table.insert(info, { "  " .. k, "Title" })
        table.insert(info, { ": " })
        local hl = type(v) == "string" and "String"
            or type(v) == "number" and "Number"
            or "Normal"
        table.insert(info, { vim.inspect(v), hl })
        table.insert(info, { "\n" })
    end
end

M.zotero_info = function()
    if not vim.tbl_contains(config.filetypes, vim.o.filetype) then
        zwarn("zotcite doesn't support " .. vim.o.filetype .. " filetype.")
        return
    end

    local out_lines = {}
    insert_info(out_lines, "Init information", require("zotcite.config").info)

    insert_info(out_lines, "Zotero information", require("zotcite.zotero").info())

    local w = require("zotcite").get_warns()
    if #w > 0 then
        table.insert(out_lines, { "Know problems:\n", "Statement" })
        for _, v in pairs(w) do
            table.insert(out_lines, { v .. "\n", "WarningMsg" })
        end
    end
    vim.schedule(function() vim.api.nvim_echo(out_lines, false, {}) end)
end

local finish_open_attachment = function(_, idx)
    if idx then require("zotcite.utils").open(sel_list[idx]) end
end

M.open_attachment = function()
    local zotkey = M.citation_key()
    local apath = M.PDFPath(zotkey, finish_open_attachment)
    if type(apath) == "string" then require("zotcite.utils").open(apath) end
end

return M
