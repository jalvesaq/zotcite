local M = {}

M.zwarn = function(s) vim.notify(s, vim.log.levels.WARN, { title = "zotcite" }) end

M.setup = function(opts)
    if opts then require("zotcite.config").update_config(opts) end
    vim.api.nvim_create_user_command("Zinfo", require("zotcite.get").zotero_info, {})
    vim.cmd("autocmd BufNewFile,BufRead * lua require('zotcite.config').init()")
end

return M
