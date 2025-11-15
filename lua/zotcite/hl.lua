local config = require("zotcite.config").get_config()

local M = {}

--- Highlight citation key and add virtual text
---@param ns integer Namespace id
---@param i integer Line
---@param s integer Column
---@param e integer End column
---@param a string
local vt_citation = function(ns, i, s, e, c, a)
    if not a then return end
    a = a:gsub("%-", "_")
    local set_m = vim.api.nvim_buf_set_extmark
    set_m(0, ns, i - 1, s - 1, { end_col = e, hl_group = "Ignore", conceal = "" })
    set_m(
        0,
        ns,
        i - 1,
        c,
        { virt_text = { { a, "Identifier" } }, virt_text_pos = "inline" }
    )
end

local vt_citations_md = function(ac, ns, lines)
    local kp = "@[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]"
    local a = ""
    for k, v in pairs(lines) do
        local i = 1
        while true do
            local s, e = v:find(kp, i)
            if not s or not e then break end
            a = ac[v:sub(s + 1, e)]
            vt_citation(ns, k, s, e, s, a)
            i = e + 1
        end
    end
end

local vt_citations_bib = function(ac, ns, lines)
    local kp = "[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]"
    local a = ""

    for k, v in pairs(lines) do
        if v:find("^@%S*{.*,%s*$") then
            local s, e = v:find(kp)
            if s and e then
                a = ac[v:sub(s, e)]
                vt_citation(ns, k, s, e, e, a)
            end
        end
    end
end

local vt_citations_typ = function(ac, ns, lines)
    local kp = "<[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]>"
    local a = ""
    for k, v in pairs(lines) do
        local i = 1
        while true do
            local s, e = v:find(kp, i)
            if not s or not e then break end
            a = ac[v:sub(s + 1, e - 1)]
            vt_citation(ns, k, s, e, e, a)
            i = e + 1
        end
    end
end

local vt_citations_tex = function(ac, ns, lines)
    local kp1 = "\\%w*cit.*{"
    local kp2 = "[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]"
    local a = ""
    for k, v in pairs(lines) do
        local i = 1
        while true do
            local s, e = v:find(kp1, i)
            if not s or not e then break end
            local j = e
            local l = v:find("%}", j)
            if not l then l = 1000 end
            while j < l do
                local s2, e2 = v:find(kp2, j)
                if not s2 or not e2 then break end
                a = ac[v:sub(s2, e2)]
                vt_citation(ns, k, s2, e2, e2, a)
                j = e2 + 1
            end
            i = e + 1
        end
    end
end

M.citations = function()
    if not config.hl_cite_key then return end

    local ac = require("zotcite.zotero").get_all_citations()
    local ns = vim.api.nvim_create_namespace("ZCitation")
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    if not vim.tbl_contains({ "tex", "rnoweb", "bib" }, vim.bo.filetype) then
        vt_citations_md(ac, ns, lines)
    end
    if vim.bo.filetype == "typst" then
        vt_citations_typ(ac, ns, lines)
    elseif vim.bo.filetype == "tex" or vim.bo.filetype == "rnoweb" then
        vt_citations_tex(ac, ns, lines)
    elseif vim.bo.filetype == "bib" then
        vt_citations_bib(ac, ns, lines)
    end
end

return M
