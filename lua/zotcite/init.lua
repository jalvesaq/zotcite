local M = {}

M.zwarn = function(s) vim.notify(s, vim.log.levels.WARN, { title = "zotcite" }) end

--- Setup
---@param opts? ZotciteUserOpts
M.setup = function(opts)
    if opts then require("zotcite.config").update_config(opts) end
end

return M
