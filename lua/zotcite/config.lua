---@class BibVirtTxt
---@field latex? boolean
---@field markdown? boolean
---@field pandoc? boolean
---@field quarto? boolean
---@field rmd? boolean
---@field rnoweb? boolean
---@field typst? boolean
---@field vimwiki? boolean

---@class ZotciteUserOpts
---Whether to syntax highlight citation keys
---@field hl_cite_key? boolean
---Save and update a bib file; add the
---zotcite complement as virtual text
---@field bib_and_vt? BibVirtTxt
---Reference field to as sorting key by :Zseek
---@field sort_key? string
---Value to set the Vim option 'conceallevel'
---@field conceallevel? 0 | 1 | 2
---Freeze Neovim after opening a PDF attachment
---@field wait_attachment? boolean
---Open PDF attachments in Zotero
---@field open_in_zotero? boolean
---Space separated list of file types
---for which Zotcite is enabled
---@field filetypes? string[]
---Register Markdown parser for Quarto and RMarkdown
---@field register_treesitter? boolean
---Absolute path to `python3` executable
---@field python_path? string
---Application to extract notes from PDF documents
---@field pdf_extractor? '"pdfnotes.py"' | '"pdfnotes2.py"'
---Template for citation keys
---@field citation_template? string
---Path to `zotero.sqlite`
---@field SQL_path? string
---Zotero encoding (by default, "utf-8" on Linux
---and "latin1" on Windows)
---@field zotero_encoding? string
---Temporary directory
---@field tmpdir? string
---Fields to be excluded from Zotero references
---@field exclude_fields? string
---String used to separate the year from the
---page in references (by default, ", p. ")
---@field year_page_sep? string
---@field open_cmd? string Command to open attachments
---Space separated list of words from title to be
---excluded from citation keys
---@field banned_words? string

---@type ZotciteUserOpts
local config = {
    hl_cite_key = true,
    bib_and_vt = {
        latex = true,
        markdown = false,
        pandoc = false,
        quarto = false,
        rmd = false,
        rnoweb = true,
        typst = false,
        vimwiki = false,
    },
    sort_key = "dateModified",
    conceallevel = 2,
    wait_attachment = false,
    open_in_zotero = false,
    filetypes = {
        "latex",
        "markdown",
        "pandoc",
        "quarto",
        "rmd",
        "rnoweb",
        "typst",
        "vimwiki",
    },
    register_treesitter = true,
    zrunning = false,
    zotcite_home = nil,
    python_path = "python3",
    pdf_extractor = "pdfnotes.py", -- Default: "pdfnotes.py", alternative: "pdfnotes2.py"
    log = {},
}

local did_global_init = false
local first_buf

local zwarn = require("zotcite").zwarn

local M = {}

local b = {}

M.show = function()
    local info = {}
    for k, v in pairs(config) do
        table.insert(info, { k, "Identifier" })
        table.insert(info, { " = ", "Operator" })
        table.insert(info, { vim.inspect(v) .. "\n" })
    end
    vim.schedule(function() vim.api.nvim_echo(info, false, {}) end)
end

M.update_config = function(opts)
    for k, v in pairs(opts) do
        config[k] = v
    end

    config.bib_and_vt.latex = true
    config.bib_and_vt.tex = true
    config.bib_and_vt.rnoweb = true

    if config.citation_template then
        vim.env.ZCitationTemplate = config.citation_template
    end
    if config.banned_words then vim.env.ZBannedWords = config.banned_words end
    if config.SQL_path then vim.env.ZoteroSQLpath = config.SQL_path end
    if config.tmpdir then vim.env.Zotcite_tmpdir = config.tmpdir end
    if config.exclude_fields then vim.env.Zotcite_exclude = config.exclude_fields end
    if config.year_page_sep then vim.env.ZYearPageSep = config.year_page_sep end
    if vim.env.Zotero_encoding then
        zwarn(
            "The environment variable `Zotero_encoding` now is a config option: `zotero_encoding`."
        )
    end
    if config.zotero_encoding then vim.env.ZoteroEncoding = config.zotero_encoding end
    if config.register_treesitter then
        vim.treesitter.language.register("markdown", { "quarto", "rmd" })
    end
end

M.has_buffer = function(bufnr)
    for _, v in pairs(b) do
        if v.bufnr == bufnr then return v end
    end
    return nil
end

M.get_b = function() return b end

M.set_collection = function(bufnr, collection)
    for k, v in pairs(b) do
        if v.bufnr == bufnr then
            b[k].zotcite_cllctn = collection
            return
        end
    end
end

local new_buffer = function(bnr) table.insert(b, { bufnr = bnr, zotcite_cllctn = "" }) end

local set_path = function()
    config.zotcite_home = debug.getinfo(1).short_src:gsub("/lua.*", "") .. "/python3"
    if vim.fn.has("win32") == 1 then
        local zpath = config.zotcite_home:gsub("/", "\\")
        if not vim.env.PATH:find(zpath) then
            vim.env.PATH = zpath .. ";" .. vim.env.PATH
        end
    else
        if not vim.env.PATH:find(config.zotcite_home) then
            vim.env.PATH = config.zotcite_home .. ":" .. vim.env.PATH
        end
    end
end

local global_init = function()
    if vim.fn.has("python3") == 0 then
        zwarn("zotcite requires python3")
        table.insert(config.log, "Python3 provider not working.")
        return false
    end

    vim.cmd("py3 import os")

    -- Start ZoteroEntries
    vim.cmd.py3("from zotero import ZoteroEntries")
    vim.cmd.py3("ZotCite = ZoteroEntries()")
    local info = vim.fn.py3eval("ZotCite.Info()")
    if info == vim.NIL then
        zwarn("Failed to run the Python command `ZotCite.Info()`")
        return false
    end

    config.zrunning = true

    vim.env.Zotcite_tmpdir = vim.fn.expand(info["tmpdir"])
    config.data_dir = vim.fn.expand(info["data dir"])
    config.attach_dir = vim.fn.expand(info["attachments dir"])

    set_path()
    vim.env.RmdFile = vim.fn.expand("%:p")

    vim.api.nvim_create_user_command("Zrefs", require("zotcite.utils").add_yaml_refs, {})
    vim.api.nvim_create_user_command(
        "Zseek",
        function(tbl)
            require("zotcite.seek").refs(tbl.args, require("zotcite.seek").print)
        end,
        { nargs = "?", desc = "Zotcite: seek references" }
    )
    vim.api.nvim_create_user_command(
        "Znote",
        function(tbl) require("zotcite.get").note(tbl.args) end,
        { nargs = "?", desc = "Zotcite: insert Zotero notes" }
    )
    vim.api.nvim_create_user_command(
        "Zannotations",
        function(tbl) require("zotcite.get").annotations(tbl.args, false) end,
        { nargs = "?", desc = "Zotcite: insert Zotero annotations" }
    )
    vim.api.nvim_create_user_command(
        "Zselectannotations",
        function(tbl) require("zotcite.get").annotations(tbl.args, true) end,
        { nargs = "?", desc = "Zotcite: insert Zotero annotations" }
    )

    vim.api.nvim_create_user_command(
        "Zpdfnote",
        function(tbl) require("zotcite.get").PDFNote(tbl.args) end,
        { nargs = "?", desc = "Zotcite: insert PDF annotations" }
    )
    vim.api.nvim_create_user_command(
        "Zodt2md",
        function(tbl) require("zotcite").ODTtoMarkdown(tbl.args) end,
        { nargs = 1, desc = "Zotcite: convert ODT to Markdown" }
    )
    vim.api.nvim_create_user_command("Zconfig", require("zotcite.config").show, {})
    require("zotcite.get").collection_name(first_buf)
    return true
end

M.init = function()
    -- Disable for LSP popup windows
    if vim.o.buftype == "nofile" then return end

    -- Do this only once
    if not did_global_init then
        did_global_init = true
        if vim.v.vim_did_enter == 0 then
            vim.api.nvim_create_autocmd("VimEnter", {
                callback = function() vim.schedule(global_init) end,
            })
        else
            vim.schedule(global_init)
        end
    end

    local bnr = vim.api.nvim_get_current_buf()
    first_buf = bnr
    if M.has_buffer(bnr) then return end

    -- But repeat this for every buffer
    if not vim.tbl_contains(config.filetypes, vim.bo[bnr].filetype) then return end
    new_buffer(bnr)

    local create_map = function(m, p, s, c, d)
        local opts = { silent = true, noremap = true, expr = false, desc = d }
        if vim.fn.hasmapto(p, m) == 1 then
            vim.api.nvim_buf_set_keymap(bnr, m, p, c, opts)
        else
            vim.api.nvim_buf_set_keymap(bnr, m, s, c, opts)
        end
    end

    create_map(
        "i",
        "<Plug>ZCite",
        "<C-X><C-B>",
        "<Cmd>lua require('zotcite.get').citation()<CR>",
        "Zotcite: insert citation"
    )
    create_map(
        "n",
        "<Plug>ZOpenAttachment",
        "<Leader>zo",
        "<Cmd>lua require('zotcite.get').open_attachment()<CR>",
        "Zotcite: open attachment"
    )
    create_map(
        "n",
        "<Plug>ZViewDocument",
        "<Leader>zv",
        "<Cmd>lua require('zotcite.utils').view_document()<CR>",
        "Zotcite: view document"
    )
    create_map(
        "n",
        "<Plug>ZCitationInfo",
        "<Leader>zi",
        "<Cmd>lua require('zotcite.get').reference_data('ayt')<CR>",
        "Zotcite: show reference info (short)"
    )
    create_map(
        "n",
        "<Plug>ZCitationCompleteInfo",
        "<Leader>za",
        "<Cmd>lua require('zotcite.get').reference_data('raw')<CR>",
        "Zotcite: show reference info (complete)"
    )
    create_map(
        "n",
        "<Plug>ZCitationYamlRef",
        "<Leader>zy",
        "<Cmd>lua require('zotcite.get').yaml_ref()<CR>",
        "Zotcite: show reference as YAML"
    )
    create_map(
        "n",
        "<Plug>ZExtractAbstract",
        "<leader>zb",
        "<Cmd>lua require('zotcite.get').abstract()<CR>",
        "Zotcite: Paste abstract note in current buffer"
    )
    vim.o.conceallevel = config.conceallevel
    vim.treesitter.start(bnr)
    if config.bib_and_vt[vim.o.filetype] then
        vim.api.nvim_create_autocmd(
            "InsertLeave",
            { buffer = bnr, callback = require("zotcite.hl").citations }
        )
    end
    vim.api.nvim_create_autocmd(
        "BufWritePre",
        { buffer = bnr, callback = require("zotcite.bib").update }
    )
    vim.api.nvim_create_autocmd("BufWritePost", {
        buffer = bnr,
        callback = function(ev) require("zotcite.get").collection_name(ev.buf) end,
    })
    require("zotcite.hl").citations()
end

M.get_config = function() return config end

M.inited = function() return did_global_init end

return M
