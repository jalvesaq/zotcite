local zwarn = require("zotcite").zwarn

local last_line = 0
local z_ls = {
    name = "zotero_ls",
    client_id = nil,
    initialized = false,
    stopped = true,
}

local compl_region = true

--- Resolve selected menu item
---@param zkey string
local resolve = function(zkey)
    local ref = vim.fn.py3eval('ZotCite.GetRefData("' .. zkey .. '")')
    if not ref then return nil end

    local doc = ""
    local ttl = " "
    if ref.title then ttl = ref.title end
    local etype = string.gsub(ref.etype, "([A-Z])", " %1")
    etype = string.lower(etype)
    doc = "`" .. etype .. "`" .. "\n\n**" .. ttl .. "**\n\n"
    if ref.etype == "journalArticle" and ref.publicationTitle then
        doc = doc .. "*" .. ref.publicationTitle .. "*\n\n"
    elseif ref.etype == "bookSection" and ref.bookTitle then
        doc = doc .. "In *" .. ref.bookTitle .. "*\n\n"
    end
    if ref.alastnm then doc = doc .. ref.alastnm end
    if ref.year then
        doc = doc .. " (" .. ref.year .. ") "
    else
        doc = doc .. " (????) "
    end
    return doc
end

--- Fill completion menu
---@param lnum integer Line number
---@param char integer Cursor column
---@return table | nil
local complete = function(lnum, char)
    local line = vim.api.nvim_buf_get_lines(0, lnum, lnum + 1, true)[1]
    local subline = line:sub(1, char)
    local word
    if vim.bo.filetype == "rnoweb" or vim.bo.filetype == "latex" then
        word = subline:match(".*{.-(%S+)$")
    else
        word = subline:match(".*@(%S+)$")
    end
    if not word then return end

    local compl_items = {}
    local bnm = vim.api.nvim_buf_get_name(0)
    if vim.fn.has("win32") == 1 then bnm = string.gsub(tostring(bnm), "\\", "/") end
    local itms = vim.fn.py3eval('ZotCite.GetMatch("' .. word .. '", "' .. bnm .. '")')
    local text_edit_range = {
        start = {
            line = lnum,
            character = char - 1,
        },
        ["end"] = {
            line = lnum,
            character = char,
        },
    }
    if itms then
        for _, v in pairs(itms) do
            local txt = v[2] .. " " .. v[3]
            if vim.fn.strwidth(txt) > 58 then
                txt = vim.fn.strcharpart(txt, 0, 58) .. "⋯"
            end
            local nt = v[1]
            if vim.bo.filetype == "rnoweb" or vim.bo.filetype == "latex" then
                nt = nt:match("^(.-)%-")
            end

            table.insert(compl_items, {
                label = txt,
                kind = vim.lsp.protocol.CompletionItemKind.Variable,
                textEdit = {
                    newText = nt,
                    range = text_edit_range,
                },
            })
        end
    end
    return compl_items
end

--- Hover implementation
---@param lnum integer Line number
---@param char integer Cursor column
---@return table | nil
local hover = function(lnum, char)
    local line = vim.api.nvim_buf_get_lines(0, lnum, lnum + 1, true)[1]

    -- Find zotero key
    local k = char
    local pre = line:sub(1, k):match(".*@(.*)")
    if not pre then return end
    local pos = line:sub(k + 1, -1):match("^(%S*).*")
    if not pos then return end
    local subline = pre .. pos
    local zkey = subline:match(
        "^([0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z])"
    )
    if not zkey then return end
    local res = resolve(zkey)
    if not res then return end
    local i, j = line:find(zkey .. "[%w%-0-9]*")
    if i then
        return {
            range = {
                start = {
                    line = lnum,
                    character = i - 1,
                },
                ["end"] = {
                    line = lnum,
                    character = j,
                },
            },
            contents = res,
        }
    end
    return { contents = res }
end

--- Get list of "zotero_ls" servers attached to current buffer
---@return integer[]
local function get_z_id()
    local cids = vim.lsp.get_clients({ buffer = vim.api.nvim_get_current_buf() })
    local ids = {}
    for _, v in pairs(cids) do
        if v.name == z_ls.name then table.insert(ids, v.id) end
    end
    return ids
end

--- This function receives 4 arguments: method, params, callback, notify_callback
local function lsp_request(method, params, callback, _)
    if method == "textDocument/completion" then
        if not compl_region then return end
        local compl_items = complete(params.position.line, params.position.character)
        callback(nil, {
            isIncomplete = false,
            is_incomplete_forward = false,
            is_incomplete_backward = true,
            items = compl_items,
        })
    elseif method == "completionItem/resolve" then
        require("zotcite.hl").citations()
        local zotkey = params.textEdit.newText:gsub("%-.*", "")
        local detail = resolve(zotkey)
        if detail then
            params.detail = detail
            callback(nil, params)
        end
    elseif method == "textDocument/hover" then
        if not compl_region then return end
        local res = hover(params.position.line, params.position.character)
        if res then callback(nil, res) end
    elseif method == "initialize" then
        callback(nil, {
            capabilities = {
                textDocument = {
                    completion = { completionItem = { snippetSupport = false } },
                },
                hoverProvider = true,
                completionProvider = {
                    resolveProvider = true,
                    triggerCharacters = { "%w" },
                    allCommitCharacters = { " ", "\n", "," },
                },
            },
        })
    elseif method == "shutdown" then
        z_ls.stopped = true
        local zid = get_z_id()
        if #zid > 0 then
            for _, v in pairs(zid) do
                if vim.lsp.buf_is_attached(0, v) then vim.lsp.buf_detach_client(0, v) end
                vim.lsp.stop_client(zid)
            end
        end
    else
        zwarn(
            string.format(
                'LSP method "%s" not implemented. Received `params`:\n%s',
                vim.inspect(method),
                vim.inspect(params)
            )
        )
    end
end

--- This function receives two arguments: method, params
local function lsp_notify(method, _)
    if method == "initialized" then
        z_ls.initialized = true
        z_ls.stopped = false
    end
end

-- Ver ~/.local/share/nvim/site/pack/core/opt/none-ls.nvim/lua/null-ls/rpc.lua
local function lsp_start(_, _)
    return {
        request = lsp_request,
        notify = lsp_notify,
        is_closing = function() return z_ls.stopped end,
        terminate = function() z_ls.stopped = true end,
    }
end

--- Set the value of `compl_region` which indicates if the cursor is in a
--- region where the completion of Zotero's keys is meaningful for Rnoweb or
--- LaTeX documents
local function set_compl_region_rnw()
    local curpos = vim.api.nvim_win_get_cursor(0)
    if not curpos then
        compl_region = false
        return
    end
    local line = vim.api.nvim_buf_get_lines(0, curpos[1] - 1, curpos[1], true)[1]
    local subline = line:sub(1, curpos[2])
    local pre, pos = subline:match(".*(\\cite%S*{)(.*)")
    if pre and not pos:find("}") then
        compl_region = true
    else
        compl_region = false
    end
end

--- Set the value of `compl_region` which indicates if the cursor is in a
--- region where the completion of Zotero's keys is meaningful for Markdown
--- documents
local function set_compl_region_md()
    local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, true)
    local lnum = last_line

    -- Check if we are within normal markdown text
    compl_region = true
    for i = lnum, 1, -1 do
        if string.find(lines[i], "^```{") then
            -- within code block
            compl_region = false
            break
        else
            if string.find(lines[i], "^```$") then
                -- after a code block
                break
            else
                if
                    (string.find(lines[i], "^---$") or string.find(lines[i], "^%.%.%.$"))
                    and i > 1
                then
                    -- after YAML front matter
                    break
                else
                    if string.find(lines[i], "^---$") and i == 1 then
                        -- within YAML front matter
                        compl_region = false
                        break
                    end
                end
            end
        end
    end
end

--- Call the appropriate function to set the value `compl_region`
local function on_cursor_move()
    if vim.bo.filetype == "rnoweb" or vim.bo.filetype == "latex" then
        set_compl_region_rnw()
    end
    local curpos = vim.api.nvim_win_get_cursor(0)
    if not curpos then return end
    local curline = curpos[1]
    if curline == last_line then return end
    last_line = curline
    set_compl_region_md()
end

local M = {}

--- Start or enable the language server
function M.start()
    -- TODO: remove this when nvim 0.12 is released
    if not vim.lsp.config then return end

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = vim.api.nvim_get_current_buf(),
        callback = on_cursor_move,
    })

    local config = require("zotcite.config").get_config()
    vim.lsp.config(z_ls.name, { cmd = lsp_start, filetypes = config.filetypes })
    if z_ls.client_id then
        vim.lsp.enable(z_ls.name)
    else
        z_ls.client_id = vim.lsp.start({ name = z_ls.name, cmd = lsp_start })
    end
end

return M
