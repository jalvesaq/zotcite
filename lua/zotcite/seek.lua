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
    local resp = {}
    for _, v in pairs(refs) do
        local item = {
            key = v.zotkey,
            author = v.alastnm,
            year = v.year,
            ttl = v.title,
            abstract = v.abstractNote,
        }
        table.insert(resp, item)
    end
    if #resp == 0 then
        vim.schedule(
            function() vim.api.nvim_echo({ { "No matches found." } }, false, {}) end
        )
    end
    return resp
end

M.print = function(ref)
    local msg = {
        { ref.value.author, "Identifier" },
        { " " },
        { ref.value.year, "Number" },
        { " " },
        { ref.value.title, "Title" },
    }
    vim.schedule(function() vim.api.nvim_echo(msg, false, {}) end)
end

--- Use telescope to find and select a reference
---@param key string Pattern to search
---@param cb function Callback function
M.refs = function(key, cb)
    local mtchs = get_match(key)
    local references = {}

    for _, v in pairs(mtchs) do
        local room = vim.o.columns - #v.year - #v.author - 3
        local title = v.ttl
        if #title > room then title = string.sub(title, 0, room) end
        table.insert(references, {
            display = v.author .. " " .. v.year .. " " .. title,
            author = v.author,
            year = v.year,
            title = v.ttl,
            abstract = v.abstract,
            citation_key = v.key,
        })
    end

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
                            { width = 40 }, -- Author
                            { remaining = true },
                            { width = 5 }, -- Year
                            { remaining = true }, -- Title
                        },
                    })
                    return {
                        value = entry,
                        display = function(e)
                            return displayer({
                                { e.value.author, "Identifier" },
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
                    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })

                    -- Use the abstract directly from the entry
                    local preview_text = string.format(
                        "# %s\n\n%s\n",
                        entry.value.title,
                        entry.value.abstract or "No abstract available."
                    )
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
