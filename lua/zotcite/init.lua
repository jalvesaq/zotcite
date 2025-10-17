local M = {}

M.zwarn = function(s) vim.notify(s, vim.log.levels.WARN, { title = "zotcite" }) end

M.user_opts = nil

--- Setup
---@param opts? ZotciteUserOpts
M.setup = function(opts)
    if opts then M.user_opts = opts end
end

return M
