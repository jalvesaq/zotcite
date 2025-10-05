local zwarn = require("zotcite").zwarn
local config = require("zotcite.config").get_config()

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
    if config.bib_and_vt[vim.o.filetype] then
        zwarn("Could not find the '\\addbibresource' command.")
    end
    return nil
end

local find_typst_bib = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    for _, v in pairs(lines) do
        if v and v:find("#bibliography%(['\"]") then
            local bib = v:gsub("#bibliography%(['\"]", "")
            bib = bib:gsub("['\"].*", "")
            return bib
        end
    end
    if config.bib_and_vt[vim.o.filetype] then
        zwarn("Could not find the '#bibliography' identifier.")
    end
    return nil
end

local find_markdown_bib = function()
    local ybib = require("zotcite.get").yaml_field("bibliography", 0)
    if not ybib then
        if config.bib_and_vt[vim.o.filetype] then
            zwarn("Could not find 'bibliography' field in YAML header.")
        end
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
    if vim.o.filetype == "typst" then return find_typst_bib() end
    if vim.o.filetype == "tex" or vim.o.filetype == "rnoweb" then
        return find_tex_bib()
    end
    return find_markdown_bib()
end

local get_typ_citations = function()
    local kp = "<[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]>"
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

local get_md_citations = function()
    local kp = "@[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]"
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

local get_tex_citations = function()
    local kp1 = "\\%w*cit.*{"
    local kp2 = "[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]"
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
    local bib = find_bib_fn()
    if not bib then return end

    local ckeys
    if vim.o.filetype == "tex" or vim.o.filetype == "rnoweb" then
        ckeys = get_tex_citations()
    else
        ckeys = get_md_citations()
    end
    if vim.o.filetype == "typst" then
        local ck2 = get_typ_citations()
        for _, v in pairs(ck2) do
            table.insert(ckeys, v)
        end
    end
    if #ckeys == 0 then
        if bib:find(".*zotcite.bib$") and vim.fn.filereadable(bib) == 0 then
            -- Ensure that `quarto preview` will work
            vim.fn.writefile({}, bib)
        end
    else
        vim.fn.py3eval(
            'ZotCite.UpdateBib(["'
                .. table.concat(ckeys, '", "')
                .. '"], "'
                .. bib
                .. '", False)'
        )
    end
    vim.schedule(require("zotcite.hl").citations)
end

return M
