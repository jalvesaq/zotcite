local M = {}

local warns = {}

--- Warning
---@param msg string The message
---@param store boolean? Whether to store the message
M.zwarn = function(msg, store)
    vim.notify(msg, vim.log.levels.WARN, { title = "zotcite" })
    if store then table.insert(warns, msg) end
end

M.get_warns = function() return warns end

M.user_opts = nil

--- Setup
---@param opts? ZotciteUserOpts
M.setup = function(opts)
    if opts then M.user_opts = opts end
end

return M
