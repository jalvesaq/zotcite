local config = {
    hl_cite_key = true,
    conceallevel = 2,
    wait_attachment = false,
    open_in_zotero = false,
    filetypes = { "markdown", "pandoc", "rmd", "quarto", "vimwiki" },
    zrunning = false,
    zotcite_home = nil,
    log = {},
}

local did_global_init = false

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

    if config.citation_template then
        vim.env.ZCitationTemplate = config.citation_template
    end
    if config.banned_words then vim.env.ZBannedWords = config.banned_words end
    if config.zotero_SQL_path then vim.env.ZoteroSQLpath = config.zotero_SQL_path end
    if config.tmpdir then vim.env.Zotcite_tmpdir = config.tmpdir end
    if config.exclude_fields then vim.env.Zotcite_exclude = config.exclude_fields end
    if config.year_page_sep then vim.env.ZYearPageSep = config.year_page_sep end
    if vim.env.Zotero_encoding then
        zwarn(
            "The environment variable `Zotero_encoding` now is a config option: `zotero_encoding`."
        )
    end
    if config.zotero_encoding then vim.env.ZoteroEncoding = config.zotero_encoding end
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

local new_buffer = function()
    table.insert(b, { bufnr = vim.api.nvim_get_current_buf(), zotcite_cllctn = "" })
end

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
    did_global_init = true
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
    local s = require("zotcite.seek")
    vim.api.nvim_create_user_command(
        "Zseek",
        function(tbl) s.refs(tbl.args, s.print) end,
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
    return true
end

M.init = function()
    local ok = false
    for _, v in pairs(config.filetypes) do
        if vim.o.filetype == v then
            ok = true
            break
        end
    end

    if not ok then return end

    -- FIXME: Use treesitter
    vim.cmd([[
    syn match zoteroCiteKey /@[A-Z0-9]\{8}#[:_[:digit:][:lower:][:upper:]\u00FF-\uFFFF\-]\+/ contains=zoteroHidden,zoteroVisible,@NoSpell containedin=pandocPCite
    syn match zoteroCiteKey /@[A-Z0-9]\{8}#[:_[:digit:][:lower:][:upper:]\u00FF-\uFFFF\-]\+/ contains=zoteroHidden,zoteroVisible,@NoSpell
    syn match zoteroHidden  /@[A-Z0-9]\{8}#/ contained containedin=zoteroCiteKey conceal
    syn match zoteroBlank   /-\ze[0-9]/ contained containedin=zoteroCiteKey conceal cchar=  
    syn match zoteroVisible /@[A-Z0-9]\{8}#\zs[:_[:digit:][:lower:][:upper:]\u00FF-\uFFFF\-]\+/ contained containedin=zoteroCiteKey
    ]])
    if config.hl_cite_key then
        vim.cmd([[
        hi default link zoteroHidden Comment
        hi default link zoteroCiteKey Identifier
        ]])
    end

    -- Do this only once
    if not did_global_init then
        if global_init() == false then return end
    end

    -- And repeat this for every buffer
    if not M.has_buffer(vim.api.nvim_get_current_buf()) then
        new_buffer()

        local create_map = function(m, p, s, c, d)
            local opts = { silent = true, noremap = true, expr = false, desc = d }
            if vim.fn.hasmapto(p, m) == 1 then
                vim.api.nvim_buf_set_keymap(0, m, p, c, opts)
            else
                vim.api.nvim_buf_set_keymap(0, m, s, c, opts)
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
        vim.cmd("autocmd BufWritePre <buffer> lua require('zotcite.utils').check_bib()")
        vim.cmd(
            "autocmd BufWritePost <buffer> lua require('zotcite.get').collection_name(-1)"
        )
        local bn = vim.api.nvim_get_current_buf()
        vim.schedule(function() require("zotcite.get").collection_name(bn) end)
    end
end

M.get_config = function() return config end

M.inited = function() return did_global_init end

return M
