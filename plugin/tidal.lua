vim.api.nvim_create_user_command("Tidal",       function() require("tidal").toggle_terminal() end, {})
vim.api.nvim_create_user_command("TidalClaude", function() require("tidal").toggle_claude() end, {})
vim.api.nvim_create_user_command("TidalPick",   function() require("tidal").claude_landing() end, {})
