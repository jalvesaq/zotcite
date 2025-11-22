local config = require("zotcite.config").get_config()

local M = {}

M.ODTtoMarkdown = function(odt)
    require("zotcite.config").set_path()
    local mdf = vim.system({ config.python_path, "odt2md.py", odt }, { text = true })
        :wait()
    if mdf.code == 0 then
        vim.cmd("tabnew " .. mdf.stdout)
    else
        M.zwarn(mdf.stderr:gsub("\n", " "))
    end
end

M.view_document = function()
    local ext = "html"
    local fmt
    if vim.o.filetype == "quarto" then
        fmt = require("zotcite.get").yaml_field("format", vim.api.nvim_get_current_buf())
    else
        fmt = require("zotcite.get").yaml_field("output", vim.api.nvim_get_current_buf())
    end
    if type(fmt) == "table" then
        for k, _ in pairs(fmt) do
            ext = tostring(k)
            break
        end
    else
        ext = tostring(fmt)
    end
    if ext == "html_document" or ext == "revealjs" then
        ext = "html"
    elseif ext == "pdf_document" or ext == "beamer" then
        ext = "pdf"
    elseif ext == "odf_document" then
        ext = "odt"
    end
    local doc = vim.fn.expand("%:p:r") .. "." .. ext
    if vim.fn.filereadable(doc) == 0 then
        M.zwarn('File "' .. doc .. '" not found.')
        return
    end
    M.open(doc)
end

M.open = function(fpath)
    if config.wait_attachment then
        local obj
        local em
        if config.open_cmd then
            obj = vim.system({ config.open_cmd, fpath }, { text = true }):wait()
            em = "Error running `" .. config.open_cmd .. ' "' .. fpath .. '"' .. "`"
        else
            obj = vim.ui.open(fpath):wait()
            em = 'Error running `vim.ui.open("' .. fpath .. '")`'
        end
        if obj.code ~= 0 then
            em = em .. ":\n  exit code: " .. tostring(obj.code)
            if obj.stdout and obj.stdout ~= "" then em = em .. "\n  " .. obj.stdout end
            if obj.stderr and obj.stderr ~= "" then em = em .. "\n  " .. obj.stderr end
            M.zwarn(em)
        end
        return
    end
    if config.open_cmd then
        vim.system({ config.open_cmd, fpath }, { text = true })
    else
        vim.ui.open(fpath)
    end
end

return M
