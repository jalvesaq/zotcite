local M = {}

M.zwarn = function(s) vim.notify(s, vim.log.levels.WARN, { title = "zotcite" }) end

M.setup = function(opts)
    if opts then require("zotcite.config").update_config(opts) end
end

return M
