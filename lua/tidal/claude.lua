local M = {}

M.state = {
  buf       = -1,
  win       = -1,
  selection = nil,
  last_fraction = 0.33,
}

vim.o.autoread = true
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "FocusGained", "CursorHold" }, {
  group = vim.api.nvim_create_augroup("TidalClaudeChecktime", { clear = true }),
  callback = function()
    if vim.fn.getcmdwintype() == "" then vim.cmd("checktime") end
  end,
})

local function current_file_dir()
  local f = vim.api.nvim_buf_get_name(0)
  if f == "" then return vim.uv.cwd() end
  return vim.fn.fnamemodify(f, ":p:h")
end

function M.open_split(opts)
  opts = opts or {}
  local cfg = require("tidal.config").options.claude
  if vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_hide(M.state.win)
    return
  end
  local cwd = opts.cwd or current_file_dir()
  vim.cmd("botright vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * (opts.fraction or cfg.fraction)))
  vim.wo[win].winhighlight = "Normal:NormalFloat,WinSeparator:FloatBorder"
  vim.wo[win].fillchars = "vert:│"

  if vim.api.nvim_buf_is_valid(M.state.buf)
      and vim.bo[M.state.buf].buftype == "terminal" then
    vim.api.nvim_win_set_buf(win, M.state.buf)
  else
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
    M.state.buf = buf
    vim.api.nvim_create_autocmd("TermOpen", {
      buffer = buf,
      once   = true,
      callback = function()
        vim.wo[win].number         = false
        vim.wo[win].relativenumber = false
        vim.wo[win].signcolumn     = "no"
        vim.wo[win].statuscolumn   = ""
        vim.wo[win].statusline     = cfg.statusline
      end,
    })
    local argv = { cfg.cmd }
    if opts.resume then
      if type(opts.resume) ~= "string"
          or not opts.resume:match("^[%x]+%-[%x]+%-[%x]+%-[%x]+%-[%x]+$") then
        vim.notify("tidal: refusing to resume invalid session id", vim.log.levels.ERROR)
        return
      end
      table.insert(argv, "--resume")
      table.insert(argv, opts.resume)
    end
    vim.fn.jobstart(argv, { term = true, cwd = cwd })
    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { buffer = buf })
    if cfg.escape and cfg.escape ~= "" then
      vim.keymap.set("t", cfg.escape, "<Esc>", { buffer = buf })
    end
  end

  M.state.win = win
  vim.cmd("startinsert")
end

function M.toggle(fraction)
  local cfg = require("tidal.config").options.claude
  fraction = fraction or cfg.fraction
  M.state.last_fraction = fraction

  if vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_hide(M.state.win)
    M.state.win = -1
    return
  end
  if vim.api.nvim_buf_is_valid(M.state.buf)
      and vim.bo[M.state.buf].buftype == "terminal" then
    M.open_split({ fraction = fraction })
    return
  end
  if M.state.selection then
    M.open_split({
      resume   = M.state.selection.id,
      fraction = fraction,
      cwd      = M.state.selection.cwd,
    })
    return
  end
  require("tidal.sessions").landing(function()
    M.open_split({
      resume   = M.state.selection.id,
      fraction = fraction,
      cwd      = M.state.selection.cwd,
    })
  end)
end

return M
