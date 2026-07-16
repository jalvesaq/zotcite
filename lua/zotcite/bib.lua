local zwarn = require("zotcite").zwarn

local M = {}

local extract_addbibresource = function(lines)
    for _, v in pairs(lines) do
        if v:find("\\addbibresource%{") then
            local bib = v:gsub("\\addbibresource%{", "")
            bib = bib:gsub("}.*", "")
            return bib
        end
    end
    return nil
end

local extract_bibliography_texcmd = function(lines)
    for _, v in pairs(lines) do
        if v:find("\\bibliography%{") then
            local bib = v:gsub("\\bibliography%{", "")
            bib = bib:gsub("}.*", ".bib")
            return bib
        end
    end
    return nil
end

local read_lines = function(path)
    if not path or vim.fn.filereadable(path) == 0 then return nil end
    return vim.fn.readfile(path)
end

local find_root_file = function(lines)
    for _, v in pairs(lines) do
        local root = v:match("^%s*%%+%s*!%s*[Tt][Ee][Xx]%s+root%s*=%s*(.-)%s*$")
        if root and root ~= "" then return root end
    end
    return nil
end

local resolve_path = function(base_dir, path)
    if not path or path == "" then return path end
    if path:find("^/") or path:find("^%a:[/\\]") then return path end
    return vim.fn.fnamemodify(base_dir .. "/" .. path, ":p")
end

local find_tex_bib = function(dir)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)

    local bib = extract_addbibresource(lines) or extract_bibliography_texcmd(lines)
    if bib then return resolve_path(dir, bib) end

    local root = find_root_file(lines)
    if root then
        local rootpath = resolve_path(dir, root)
        local rootlines = read_lines(rootpath)
        if not rootlines then
            zwarn("Failed to read TeX root: '" .. rootpath .. "'")
            return nil
        end
        bib = extract_addbibresource(rootlines) or extract_bibliography_texcmd(lines)
        if not bib then
            zwarn(
                "Could not find the '\\addbibresource' or '\bibliography' command in TeX root '"
                    .. rootpath
                    .. "'"
            )
        end
        local rootdir = vim.fn.fnamemodify(rootpath, ":p:h")
        return resolve_path(rootdir, bib)
    end

    local tfr = require("zotcite.config").get_config().tex_fallback_root
    local fallback_root = vim.fn.fnamemodify(dir .. "/" .. tfr, ":p")
    local fallback_lines = read_lines(fallback_root)
    bib = fallback_lines and (extract_addbibresource(fallback_lines) or extract_bibliography_texcmd(fallback_lines) or nil)
    if bib then
        local rootdir = vim.fn.fnamemodify(fallback_root, ":p:h")
        return resolve_path(rootdir, bib)
    end
    zwarn("Could not find the '\\addbibresource' or '\\bibliography' command.")
    return nil
end

local find_typst_bib = function(dir)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    for _, v in pairs(lines) do
        if v and v:find("#bibliography%(") then
            return resolve_path(dir, v:match('#bibliography%(%s*"(%S-)".*'))
        end
    end
    zwarn("Could not find the `#bibliography` identifier.")
    return nil
end

local find_markdown_bib = function(dir)
    local ybib = require("zotcite.get").yaml_field("bibliography", 0)
    if not ybib then
        zwarn("Could not find 'bibliography' field in YAML header.")
        return nil
    end

    if type(ybib) == "string" then return resolve_path(dir, ybib) end

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
    local brt = require("zotcite.config").get_config().bib_relative_to
    local dir = brt == "working_dir" and vim.uv.cwd()
        or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
    if vim.bo.filetype == "typst" then
        return find_typst_bib(dir)
    elseif vim.bo.filetype == "tex" or vim.bo.filetype == "rnoweb" then
        return find_tex_bib(dir)
    end
    return find_markdown_bib(dir)
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
            local prevchar = s > 1 and v:sub(s - 1, s - 1) or ""
            if not prevchar:find("[%w/]") then table.insert(ckeys, v:sub(s + 1, e)) end
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
    local kt = require("zotcite.config").get_key_type(vim.api.nvim_get_current_buf())
    local kz = kt == "zotero"
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

    require("zotcite.zotero").update_bib(ckeys, bib, kt, false)
    vim.schedule(require("zotcite.hl").citations)
end

return M
