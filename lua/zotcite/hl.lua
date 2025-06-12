local config = require("zotcite.config").get_config()

local M = {}

local vt_citation = function(ns, i, s, e, a)
    if not a then return end
    a = a:gsub("%-", "_")
    local set_m = vim.api.nvim_buf_set_extmark
    set_m(0, ns, i - 1, s - 1, { end_col = e, hl_group = "Ignore", conceal = "" })
    set_m(
        0,
        ns,
        i - 1,
        e,
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
            vt_citation(ns, k, s, e, a)
            i = e + 1
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
            vt_citation(ns, k, s, e, a)
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
                vt_citation(ns, k, s2, e2, a)
                j = e2 + 1
            end
            i = e + 1
        end
    end
end

local vt_citations = function()
    local ac = vim.fn.py3eval("ZotCite.GetAllCitations()")
    local ns = vim.api.nvim_create_namespace("ZCitation")
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    if vim.o.filetype ~= "latex" and vim.o.filetype ~= "rnoweb" then
        vt_citations_md(ac, ns, lines)
    end
    if vim.o.filetype == "typst" then vt_citations_typ(ac, ns, lines) end
    if vim.o.filetype == "tex" or vim.o.filetype == "rnoweb" then
        vt_citations_tex(ac, ns, lines)
    end
end

local hl_zotkeys = function()
    local ns = vim.api.nvim_create_namespace("ZCitation")
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
    local kp = "@[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][%-%#]"
    local yp = "^%S*[0-9][0-9][0-9][0-9]"
    if vim.env.ZCitationTemplate and vim.env.ZCitationTemplate:find("year") then
        yp = "^%S*[0-9][0-9]"
    end
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local set_m = vim.api.nvim_buf_set_extmark
    for k, v in pairs(lines) do
        local i = 1
        while true do
            local s, e = v:find(kp, i)
            if not s or not e then break end
            set_m(0, ns, k - 1, s - 1, { end_col = e, hl_group = "Ignore", conceal = "" })
            local _, y = v:find(yp, e)
            if y then
                set_m(0, ns, k - 1, e, { end_col = y, hl_group = "Identifier" })
                set_m(
                    0,
                    ns,
                    k - 1,
                    y - 5,
                    { end_col = y - 4, hl_group = "Identifier", conceal = "_" }
                )
                e = e + 1
                local substr = v:sub(e, y)
                local j = 1
                while true do
                    local _, m = substr:find("+", j) -- old delimiter
                    if not m then
                        _, m = substr:find("%-", j)
                    end
                    if not m then break end
                    set_m(
                        0,
                        ns,
                        k - 1,
                        m + e - 2,
                        { end_col = m + e - 1, hl_group = "Identifier", conceal = "_" }
                    )
                    j = m + 1
                end
            end
            i = e + 1
        end
    end
end

M.citations = function()
    if not config.hl_cite_key then return end
    if config.bib_and_vt[vim.o.filetype] then
        vt_citations()
    else
        hl_zotkeys()
    end
end

return M
