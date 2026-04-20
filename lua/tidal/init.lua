local M = {}

function M.setup(opts)
  local config = require("tidal.config")
  config.setup(opts)

  local hl = config.options.highlights
  vim.api.nvim_set_hl(0, "TidalUser",      hl.user)
  vim.api.nvim_set_hl(0, "TidalUserBody",  hl.user_body)
  vim.api.nvim_set_hl(0, "TidalAssistant", hl.assistant)
  vim.api.nvim_set_hl(0, "TidalBody",      hl.body)

  local km = config.options.keymaps
  if km.toggle_terminal then
    vim.keymap.set("n", km.toggle_terminal, function() require("tidal.terminal").toggle() end,
      { desc = "Tidal: toggle terminal" })
  end
  if km.toggle_claude then
    vim.keymap.set("n", km.toggle_claude, function()
      require("tidal.claude").toggle(config.options.claude.fraction)
    end, { desc = "Tidal: toggle Claude (narrow)" })
  end
  if km.toggle_claude_big then
    vim.keymap.set("n", km.toggle_claude_big, function()
      require("tidal.claude").toggle(0.50)
    end, { desc = "Tidal: toggle Claude (wide)" })
  end
  if km.claude_pick then
    vim.keymap.set("n", km.claude_pick, function()
      local claude = require("tidal.claude")
      require("tidal.sessions").landing(function()
        claude.open_split({
          resume   = claude.state.selection.id,
          fraction = config.options.claude.fraction,
          cwd      = claude.state.selection.cwd,
        })
      end)
    end, { desc = "Tidal: Claude session picker" })
  end
end

function M.toggle_terminal() require("tidal.terminal").toggle() end
function M.toggle_claude(fraction) require("tidal.claude").toggle(fraction) end
function M.claude_landing(cb) require("tidal.sessions").landing(cb) end

return M
