local fzf_lua = require("fzf-lua")
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
    local preview_text
    if v.etype == "journalArticle" then
        preview_text = string.format(
            "{(%s)}\n{{%s}} {[%s]}. {<%s>}.\n\n%s\n\n{[%s]} {<%s>}",
            v.title or "",
            authors,
            v.year or "",
            v.publicationTitle or "",
            v.abstract or "No abstract available.", 
            v.etype, v.cite
        )
    elseif v.etype == "bookSection" then
        preview_text = string.format(
            "{(%s)}\n{{%s}} {[%s]}. In: {<%s>}.\n\n%s\n\n{[%s]} {<%s>}",             
            v.title or "",
            authors,
            v.year or "",
            v.publicationTitle or "",
            v.abstract or "", 
            v.etype, v.cite
        )
    else
        preview_text = string.format(
            "{(%s)}\n{{%s}} {[%s]}.\n\n%s\n\n{[%s]} {<%s>}",
            v.title or "",
            authors,
            v.year or "",
            v.abstract or "", 
            v.etype, v.cite
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
            adate = v.accessDate or v.date or "0000-00-00 000",
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
    table.sort(references, function(a, b) return (a.adate > b.adate) end)

	local entries = {}
	local previewtext = {}

	for i, ref in ipairs(references) do
		local entry_str = string.format("%s\t%-"..awidth.."s %-10s %-4s %s", ref.cite, ref.etype, ref.alastnm, ref.year, ref.title)
		entries[i] = entry_str
		previewtext[ref.cite] = format_preview(ref)
	end

	-- local function format_display(entry)
	-- 	local display = format_entry(entry)
	-- 	return { display = display, key = entry.key, full = entry }
	-- end
	--
	-- local results = vim.tbl_map(format_display, entries)


	-- fzf-lua configuration
    fzf_lua.fzf_exec(entries, {
        prompt = "Search pattern> ",
        fzf_opts = {
            ['--header'] = "Ctrl-o: Select | Enter: Open Attachment",
			['--delimiter'] = '\t',
			['--with-nth'] = '2',
			['--ansi'] = true,
        },
		previewer = {
		  _ctor = function()
				local base = require 'fzf-lua.previewer.builtin'.buffer_or_file
				local previewer = base:extend()
				function previewer:populate_preview_buf(selection)
					local citekey = selection:match("([^\t]+)")
					local previewLines = previewtext[citekey]
					local tmpbuf = self:get_tmp_buffer()
					vim.api.nvim_set_option_value("syntax", "zoteropreview", { buf = tmpbuf })
					vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, vim.split(previewLines, '\n'))
					self:set_preview_buf(tmpbuf)
				end
		    return previewer
		  end,
		},
		actions = {
            ['default'] = function(selected)
                local citekey = selected[1]:match("([^\t]+)")
                if citekey then
                    require("zotcite.get").open_attachment(citekey)
                end
            end,
            ['ctrl-o'] = function(selected)
                local citekey = selected[1]:match("([^\t]+)")
                if citekey and cb then
                    cb(citekey)
                end
            end,
        },
    })


    -- pickers
    --     .new({}, {
    --         prompt_title = "Search pattern",
    --         results_title = "Zotero references",
    --         finder = finders.new_table({
    --             results = references,
    --             entry_maker = function(entry)
    --                 local displayer = entry_display.create({
    --                     separator = " ",
    --                     items = {
    --                         { width = awidth }, -- Author
    --                         { width = 4 }, -- Year
    --                         { remaining = true }, -- Title
    --                     },
    --                 })
    --                 return {
    --                     value = entry,
    --                     display = function(e)
    --                         return displayer({
    --                             { e.value.alastnm, "Identifier" },
    --                             { e.value.year, "Number" },
    --                             { e.value.title, "Title" },
    --                         })
    --                     end,
    --                     ordinal = entry.display,
    --                 }
    --             end,
    --         }),
    --         sorter = sorters.generic_sorter({}),
    --         previewer = previewers.new_buffer_previewer({
    --             define_preview = function(self, entry, _)
    --                 local bufnr = self.state.bufnr
    --                 vim.api.nvim_set_option_value(
    --                     "syntax",
    --                     "zoteropreview",
    --                     { buf = bufnr }
    --                 )
    --
    --                 local preview_text = format_preview(entry.value)
    --
    --                 vim.api.nvim_buf_set_lines(
    --                     bufnr,
    --                     0,
    --                     -1,
    --                     false,
    --                     vim.split(preview_text, "\n")
    --                 )
    --             end,
    --         }),
    --         attach_mappings = function(prompt_bufnr, map)
    --         map("i", "<C-o>", function()
    --             local selection = action_state.get_selected_entry()
    --             actions.close(prompt_bufnr)
    --             -- Handle the selected reference here
    --             cb(selection)
    --         end)
    --         map("i", "<CR>", function()
    --             local selection = action_state.get_selected_entry()
    --             -- actions.close(prompt_bufnr)
    --             print(selection.value)
    --             require("zotcite.get").open_attachment(selection.value.cite)
    --         end)
    --         return true
    --         end,
    --     })
        -- :find()
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
