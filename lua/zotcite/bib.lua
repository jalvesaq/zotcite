local zwarn = require("zotcite").zwarn

local M = {}

local find_tex_bib = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    for _, v in pairs(lines) do
        if v:find("\\addbibresource%{") then
            local bib = v:gsub("\\addbibresource%{", "")
            bib = bib:gsub("}.*", "")
            return bib
        end
    end
    zwarn("Could not find the '\\addbibresource' command.")
    return nil
end

local find_typst_bib = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    for _, v in pairs(lines) do
        if v and v:find("#bibliography%(") then
            return v:match('#bibliography%(%s*"(%S-)".*')
        end
    end
    zwarn("Could not find the `#bibliography` identifier.")
    return nil
end

local find_markdown_bib = function()
    local ybib = require("zotcite.get").yaml_field("bibliography", 0)
    if not ybib then
        zwarn("Could not find 'bibliography' field in YAML header.")
        return nil
    end

    if type(ybib) == "string" then return ybib end

    local bib = nil
    if type(ybib) == "table" then
        for _, v in pairs(ybib) do
            if type(v) == "string" then
                bib = v
                if v:find("zotcite.bib") then break end
            else
                zwarn('Invalid "bibliography" field: ' .. vim.inspect(bib))
                return
            end
        end
    end
    return bib
end

local find_bib_fn = function()
    if vim.bo.filetype == "typst" then return find_typst_bib() end
    if vim.bo.filetype == "tex" or vim.bo.filetype == "rnoweb" then
        return find_tex_bib()
    end
    return find_markdown_bib()
end

local get_typ_citations = function(kz)
    local kp = kz and "<[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]>"
        or "<[%w%-\192-\244\128-\191]+>"
    local ckeys = {}
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    for _, v in pairs(lines) do
        local i = 1
        while true do
            local s, e = v:find(kp, i)
            if not s or not e then break end
            table.insert(ckeys, v:sub(s + 1, e - 1))
            i = e + 1
        end
    end
    return ckeys
end

local get_md_citations = function(kz)
    local kp = kz and "@[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]"
        or "@[%w%-\192-\244\128-\191]+"
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local ckeys = {}
    for _, v in pairs(lines) do
        local i = 1
        while true do
            local s, e = v:find(kp, i)
            if not s or not e then break end
            table.insert(ckeys, v:sub(s + 1, e))
            i = e + 1
        end
    end
    return ckeys
end

local get_tex_citations = function(kz)
    local kp1 = "\\%w*cit.*{"
    local kp2 = kz and "[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]"
        or "[%w%-\192-\244\128-\191]+"
    local ckeys = {}
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    for _, v in pairs(lines) do
        local i = 1
        while true do
            local s, e = v:find(kp1, i)
            if not s or not e then break end
            local j = e
            while true do
                local s2, e2 = v:find(kp2, j)
                if not s2 or not e2 then break end
                table.insert(ckeys, v:sub(s2, e2))
                j = e2 + 1
            end
            i = e + 1
        end
    end
    return ckeys
end

M.update = function()
    local kz = require("zotcite.config").get_config().key_type == "zotero"
    local ckeys
    if vim.o.filetype == "tex" or vim.o.filetype == "rnoweb" then
        ckeys = get_tex_citations(kz)
    else
        ckeys = get_md_citations(kz)
    end
    if vim.o.filetype == "typst" then
        local ck2 = get_typ_citations(kz)
        for _, v in pairs(ck2) do
            table.insert(ckeys, v)
        end
    end
    if #ckeys == 0 then return end

    local bib = find_bib_fn()
    if not bib then return end

    local config = require("zotcite.config").get_config()
    require("zotcite.zotero").update_bib(ckeys, bib, config.key_type, false)
    vim.schedule(require("zotcite.hl").citations)
end

return M
