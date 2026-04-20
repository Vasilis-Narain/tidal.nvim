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
  },
  sessions = {
    max       = 20,
    max_bytes = 256 * 1024,
  },
  highlights = {
    user      = { link = "Title" },
    user_body = { link = "Comment" },
    assistant = { link = "Special" },
    body      = { link = "Normal" },
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
