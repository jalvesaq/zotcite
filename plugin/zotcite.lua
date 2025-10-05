local did_plugin = false
if did_plugin then return end
did_plugin = true
vim.api.nvim_create_user_command("Zinfo", "lua require('zotcite.get').zotero_info()", {})
