local config = require("zotcite.config").get_config()
local zwarn = require("zotcite").zwarn
local seek = require("zotcite.seek")

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
    local repl = vim.fn.py3eval('ZotCite.GetAttachment("' .. zotkey .. '")')
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

local citation_key_hl = function(line, pos)
    pos = pos + 1
    if line:sub(pos, pos) == "@" then pos = pos + 1 end
    local i = pos
    local k = line:sub(i, i)
    while i > 0 and (k == "#" or k == "+" or k == "-" or is_valid_char(k)) do
        i = i - 1
        if line:sub(i, i) == "@" then
            local j = i + 1
            k = line:sub(j, j)
            while j <= #line and is_valid_char(k) do
                j = j + 1
                k = line:sub(j, j)
            end
            local key = line:sub(i + 1, j - 1)
            if #key == 8 then return key end
            break
        end
        k = line:sub(i, i)
    end
    return ""
end

M.citation_key = function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
    local pos = vim.api.nvim_win_get_cursor(0)[2]

    if config.bib_and_vt[vim.o.filetype] then
        return citation_key_vt(line, pos)
    end
    return citation_key_hl(line, pos)
end

M.yaml_ref = function()
    local wrd = M.citation_key()
    if wrd ~= "" then
        local repl = vim.fn.py3eval('ZotCite.GetYamlRefs(["' .. wrd .. '"])')
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
        local repl = vim.fn.py3eval('ZotCite.GetRefData("' .. wrd .. '")')
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
    local rownr = vim.api.nvim_win_get_cursor(0)[1] - 1
    local cite
    if config.bib_and_vt[vim.o.filetype] then
        cite = ref.value.key
    else
        cite = "@" .. ref.value.key .. "-" .. ref.value.cite
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
    require("zotcite.hl").citations()
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
        local repl = vim.fn.py3eval('ZotCite.GetRefData("' .. wrd .. '")')
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
    local clean = config.bib_and_vt[vim.o.filetype] and "True" or "False"
    local md = (vim.o.filetype == "tex" or vim.o.filetype == "rnoweb") and "False" or "True"
    local key = sel.value.key
    local repl = vim.fn.py3eval(
        'ZotCite.GetAnnotations("' .. key .. '", ' .. offset .. ", " .. clean .. ", " .. md .. ")"
    )
    if #repl == 0 then
        zwarn("No annotation found.")
    end
    return repl
end

local finish_annotations = function(sel)
    if not sel then return end
    local repl = get_annotations(sel)
    if #repl > 0 then
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        vim.api.nvim_buf_set_lines(0, lnum, lnum, true, repl)
        require("zotcite.hl").citations()
    end
end

local finish_annotations_selection = function(sel)
    if not sel then return end
    local raw_annotations = get_annotations(sel)
    if #raw_annotations > 0 then
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
                    local selected_annotations = {}
                    for index in pairs(selected_indices) do
                        table.insert(selected_annotations, grouped_annotations[index])
                    end
                    local lnum = vim.api.nvim_win_get_cursor(0)[1]
                    local txt = table.concat(selected_annotations, "\n\n")
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
                            local selected_annotations = {}
                            for index in pairs(selected_indices) do
                                table.insert(
                                    selected_annotations,
                                    grouped_annotations[index]
                                )
                            end
                            local lnum = vim.api.nvim_win_get_cursor(0)[1]
                            vim.api.nvim_buf_set_lines(
                                0,
                                lnum,
                                lnum,
                                true,
                                vim.split(table.concat(selected_annotations, "\n\n"), "\n")
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
    local clean = config.bib_and_vt[vim.o.filetype] and "True" or "False"
    local key = sel.value.key
    local repl = vim.fn.py3eval('ZotCite.GetNotes("' .. key .. '", ' .. clean .. ')')
    if repl == "" then
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
    local repl = vim.fn.py3eval('ZotCite.GetRefData("' .. zotkey .. '")')
    if type(repl) ~= "table" then
        zwarn("Citation key not found")
        return
    end
    local citekey
    if config.bib_and_vt[vim.o.filetype] then
        citekey = "@" .. zotkey
    else
        citekey = "@" .. zotkey .. "-" .. repl["citekey"]
    end
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

M.yaml_field = function(field, bn)
    local node = vim.treesitter.get_node({ bufnr = bn, pos = { 0, 0 } })
    if not node then
        zwarn("Error: Is treesitter enabled?")
        return nil
    end
    if node:type() ~= "minus_metadata" then return nil end

    -- FIXME: use treesitter to avoid dependence on PyYAML

    local lines = vim.api.nvim_buf_get_lines(bn, 0, -1, true)
    local nlines = #lines
    local ylines = {}
    local i = 2
    local line = ""
    local has_field = false
    while i < nlines do
        if lines[i]:find("^%s*%-%-%-%s*$") then break end
        if lines[i]:find(field .. ":") then has_field = true end
        line = lines[i]:gsub("\\", "\\\\")
        line = string.gsub(line, '"', '\\"')
        table.insert(ylines, line)
        i = i + 1
    end
    if #ylines == 0 then return nil end
    if not has_field then return nil end

    local value = vim.fn.py3eval(
        'ZotCite.GetYamlField("'
            .. field
            .. '", "'
            .. table.concat(ylines, "\002")
            .. '")'
    )
    if value == vim.NIL then return nil end

    return value
end

M.collection_name = function(bn)
    if bn == -1 then bn = vim.api.nvim_get_current_buf() end
    local newc = M.yaml_field("collection", bn)
    if not newc then return end

    if type(newc) == "table" then newc = table.concat(newc, "\002") end

    local buf = require("zotcite.config").has_buffer(bn)
    if buf then
        if
            not buf.zotcite_cllctn
            or (buf.zotcite_cllctn and buf.zotcite_cllctn ~= newc)
        then
            require("zotcite.config").set_collection(buf, newc)
            local repl = vim.fn.py3eval(
                'ZotCite.SetCollections("'
                    .. vim.fn.escape(vim.fn.expand("%:p"), "\\")
                    .. '", "'
                    .. newc
                    .. '")'
            )
            if repl ~= "" then zwarn(repl) end
        end
    end
end

M.zotero_info = function()
    local info = {}
    if not vim.tbl_contains(config.filetypes, vim.o.filetype) then
        zwarn("zotcite doesn't support " .. vim.o.filetype .. " filetype.")
        return
    end
    if config.zrunning then
        local pyinfo = vim.fn.py3eval("ZotCite.Info()")
        table.insert(info, { "Information from the Python module:\n", "Statement" })
        for k, v in pairs(pyinfo) do
            table.insert(info, { "  " .. k, "Title" }) -- FIXME: align output
            table.insert(info, { ": " .. tostring(v):gsub("\n", "") .. "\n" })
        end
    else
        if vim.tbl_contains(config.filetypes, vim.o.filetype) then
            table.insert(info, { "ZoteroEntries wasn't created.\n", "WarningMsg" })
        end
    end
    if #config.log > 0 then
        table.insert(info, { "Know problems:\n", "Statement" })
        for _, v in pairs(config.log) do
            table.insert(info, { v .. "\n", "WarningMsg" })
        end
    end
    vim.schedule(function() vim.api.nvim_echo(info, false, {}) end)
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
