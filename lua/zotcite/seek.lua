local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local entry_display = require("telescope.pickers.entry_display")

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
        for _, n in pairs(v.author) do
            table.insert(alist, n[1] .. ", " .. n[2])
        end
        authors = table.concat(alist, "; ")
    else
        authors = "?"
    end
    local preview_text
    if v.etype == "journalArticle" then
        preview_text = string.format(
            "{{%s}} {[%s]} {(%s)}. {<%s>}.\n\n%s\n",
            authors,
            v.year or "",
            v.title or "",
            v.publicationTitle or "",
            v.abstract or "No abstract available."
        )
    elseif v.etype == "bookSection" then
        preview_text = string.format(
            "{{%s}} {[%s]} {(%s)}. In: {<%s>}.\n\n%s\n",
            authors,
            v.year or "",
            v.title or "",
            v.publicationTitle or "",
            v.abstract or ""
        )
    else
        preview_text = string.format(
            "{{%s}} {[%s]} {(%s)}.\n\n%s\n",
            authors,
            v.year or "",
            v.title or "",
            v.abstract or ""
        )
    end
    return preview_text
end

--- Use telescope to find and select a reference
---@param key string Pattern to search
---@param cb function Callback function
M.refs = function(key, cb)
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
            publicationTitle = v.publicationTitle or v.bookTitle,
            author = v.author
                or v.artist
                or v.performer
                or v.director
                or v.sponsor
                or v.contributor
                or v.interviewee
                or v.cartographer
                or v.inventor
                or v.podcaster
                or v.presenter
                or v.programmer,
            alastnm = v.alastnm,
            year = v.year,
            title = v.title,
            abstract = v.abstractNote,
            key = v.zotkey,
            cite = v.citekey,
        })
    end
    if awidth > awlim then awidth = awlim end

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
                    vim.api.nvim_set_option_value(
                        "syntax",
                        "zoteropreview",
                        { buf = bufnr }
                    )

                    local preview_text = format_preview(entry.value)

                    vim.api.nvim_buf_set_lines(
                        bufnr,
                        0,
                        -1,
                        false,
                        vim.split(preview_text, "\n")
                    )
                end,
            }),
            attach_mappings = function(prompt_bufnr, map)
                map("i", "<CR>", function()
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
