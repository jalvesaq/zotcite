local config = require("zotcite.config").get_config()
local ns = vim.api.nvim_create_namespace("ZSeekPreview")

local M = {}

local get_match = function(key)
    local citeptrn = key:gsub(" .*", "")
    local refs = vim.fn.py3eval(
        'ZotCite.GetMatch("'
            .. citeptrn
            .. '", "'
            .. vim.fn.escape(vim.fn.expand("%:p"), "\\")
            .. '", True)'
    )
    if #refs == 0 then
        vim.schedule(
            function() vim.api.nvim_echo({ { "No matches found." } }, false, {}) end
        )
    end
    return refs
end

M.print = function(ref)
    local msg = {
        { ref.value.alastnm, "Identifier" },
        { " " },
        { ref.value.year, "Number" },
        { " " },
        { ref.value.title, "Title" },
    }
    vim.schedule(function() vim.api.nvim_echo(msg, false, {}) end)
end

local format_preview = function(v)
    local alist = {}
    local authors
    if v.author then
        if #v.author > 5 then
            authors = v.author[1][1] .. ", " .. v.author[1][2] .. " and others"
        else
            for _, n in pairs(v.author) do
                table.insert(alist, n[1] .. ", " .. n[2])
            end
            authors = table.concat(alist, "; ")
        end
    else
        authors = "?"
    end
    local year = v.year or "????"
    local title = v.title or "????"
    local ptitle = v.publicationTitle or "????"
    local txt
    local hl = { { g = "Identifier", s = 0, e = #authors } }
    table.insert(hl, { g = "Number", s = hl[1].e + 1, e = hl[1].e + 1 + #year })
    table.insert(hl, { g = "Title", s = hl[2].e + 1, e = hl[2].e + 1 + #title })
    if v.etype == "journalArticle" then
        txt = string.format(
            "%s %s %s. %s.\n\n%s\n",
            authors,
            year,
            title,
            ptitle,
            v.abstract or "No abstract available."
        )
        table.insert(hl, { g = "Include", s = hl[3].e + 2, e = hl[3].e + 2 + #ptitle })
    elseif v.etype == "bookSection" then
        txt = string.format(
            "%s %s %s. In: %s.\n\n%s\n",
            authors,
            year,
            title,
            ptitle,
            v.abstract or ""
        )
        table.insert(hl, { g = "Include", s = hl[3].e + 6, e = hl[3].e + 6 + #ptitle })
    else
        txt = string.format("%s %s %s.\n\n%s\n", authors, year, title, v.abstract or "")
    end
    return txt, hl
end

--- Use telescope to find and select a reference
---@param key string Pattern to search
---@param cb function Callback function
M.refs = function(key, cb)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local sorters = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local previewers = require("telescope.previewers")
    local entry_display = require("telescope.pickers.entry_display")
    local mtchs = get_match(key)
    local references = {}

    local awidth = 2
    local awlim = vim.o.columns - 140
    if awlim < 20 then awlim = 20 end
    if awlim > 60 then awlim = 60 end
    for _, v in pairs(mtchs) do
        if #v.alastnm > awidth then awidth = #v.alastnm end
        table.insert(references, {
            display = v.alastnm .. " " .. v.year .. " " .. v.title,
            etype = v.etype,
            sort_key = v[config.sort_key] or "0000-00-00 0000",
            publicationTitle = v.publicationTitle
                or v.bookTitle
                or v.proceedingsTitle
                or v.conferenceName
                or v.programTitle
                or v.blogTitle
                or v.code
                or v.dictionaryTitle
                or v.encyclopediaTitle
                or v.forumTitle
                or v.websiteTitle
                or v.seriesTitle,
            author = v.author
                or v.artist
                or v.performer
                or v.director
                or v.composer
                or v.sponsor
                or v.contributor
                or v.interviewee
                or v.cartographer
                or v.inventor
                or v.podcaster
                or v.presenter
                or v.programmer
                or v.recipient
                or v.editor
                or v.seriesEditor
                or v.translator,
            alastnm = v.alastnm,
            year = v.year,
            title = v.title,
            abstract = v.abstractNote,
            key = v.zotkey,
            cite = v.citekey,
        })
    end
    if awidth > awlim then awidth = awlim end
    table.sort(references, function(a, b) return (a.sort_key > b.sort_key) end)

    pickers
        .new({}, {
            prompt_title = "Search pattern",
            results_title = "Zotero references",
            finder = finders.new_table({
                results = references,
                entry_maker = function(entry)
                    local displayer = entry_display.create({
                        separator = " ",
                        items = {
                            { width = awidth }, -- Author
                            { width = 4 }, -- Year
                            { remaining = true }, -- Title
                        },
                    })
                    return {
                        value = entry,
                        display = function(e)
                            return displayer({
                                { e.value.alastnm, "Identifier" },
                                { e.value.year, "Number" },
                                { e.value.title, "Title" },
                            })
                        end,
                        ordinal = entry.display,
                    }
                end,
            }),
            sorter = sorters.generic_sorter({}),
            previewer = previewers.new_buffer_previewer({
                define_preview = function(self, entry, _)
                    local bufnr = self.state.bufnr
                    local preview_text, hl = format_preview(entry.value)
                    vim.api.nvim_buf_set_lines(
                        bufnr,
                        0,
                        -1,
                        false,
                        vim.split(preview_text, "\n")
                    )
                    for _, h in pairs(hl) do
                        if vim.fn.has("nvim-0.11") == 1 then
                            vim.hl.range(bufnr, ns, h.g, { 0, h.s }, { 0, h.e }, {})
                        else
                            vim.api.nvim_buf_add_highlight(bufnr, -1, h.g, 0, h.s, h.e)
                        end
                    end
                end,
            }),
            attach_mappings = function(prompt_bufnr, map)
                map({ "i", "n" }, "<CR>", function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    -- Handle the selected reference here
                    cb(selection)
                end)
                return true
            end,
        })
        :find()
end

--  text wrapping in the preview window
vim.api.nvim_create_autocmd("User", {
    pattern = "TelescopePreviewerLoaded",
    callback = function()
        vim.wo.wrap = true
        vim.wo.linebreak = true
    end,
})

return M
