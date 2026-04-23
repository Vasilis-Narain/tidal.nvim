local M = {}

M.defaults = {
  terminal = {
    shell  = nil,
    width  = 0.8,
    height = 0.8,
    border = "rounded",
  },
  claude = {
    cmd        = "claude",
    fraction   = 0.33,
    statusline = " Claude",
    escape     = "<C-q>",
  },
  sessions = {
    max           = 20,
    max_bytes     = 256 * 1024,
    delete_key    = "<M-d>",
    move_up_key   = "<C-d>",
    move_down_key = "<C-u>",
  },
  highlights = {
    user      = { fg = "#7aa2f7", bold = true },
    user_body = { fg = "#bb9af7", italic = true },
    assistant = { fg = "#e0af68", bold = true },
    body      = { fg = "#c0caf5" },
  },
  keymaps = {
    toggle_terminal   = "<leader>tt",
    toggle_claude     = "<leader>tc",
    toggle_claude_big = "<leader>tC",
    claude_pick       = "<leader>tlc",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
