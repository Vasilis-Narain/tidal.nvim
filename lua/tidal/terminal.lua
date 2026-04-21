local M = {}

local state = { buf = -1, win = -1 }

local function current_file_dir()
  local f = vim.api.nvim_buf_get_name(0)
  if f == "" then return vim.uv.cwd() end
  return vim.fn.fnamemodify(f, ":p:h")
end

local function preferred_shell(cfg_shell)
  if cfg_shell then return cfg_shell end
  if vim.fn.has("win32") == 1 then
    local bash = "C:\\Program Files\\Git\\bin\\bash.exe"
    if vim.fn.executable(bash) == 1 then return { bash, "--login", "-i" } end
  end
  return vim.o.shell
end

local function open_floating_window(opts)
  local cfg = require("tidal.config").options.terminal
  local ui = vim.api.nvim_list_uis()[1]
  local total_w, total_h = ui.width, ui.height
  local width  = opts.width  or math.floor(total_w * cfg.width)
  local height = opts.height or math.floor(total_h * cfg.height)
  local col = math.floor((total_w - width) / 2)
  local row = math.floor((total_h - height) / 2)
  local buf
  if opts.buf and vim.api.nvim_buf_is_valid(opts.buf) then
    buf = opts.buf
  else
    buf = vim.api.nvim_create_buf(false, true)
  end
  local win = vim.api.nvim_open_win(buf, true, {
    style    = "minimal",
    relative = "editor",
    width    = width,
    height   = height,
    row      = row,
    col      = col,
    border   = cfg.border,
  })
  return { buf = buf, win = win }
end

function M.toggle()
  if not vim.api.nvim_win_is_valid(state.win) then
    local cwd = current_file_dir()
    local r = open_floating_window({ buf = state.buf })
    state.buf, state.win = r.buf, r.win
    if vim.bo[state.buf].buftype ~= "terminal" then
      local shell = preferred_shell(require("tidal.config").options.terminal.shell)
      if type(shell) == "string" then shell = { shell } end
      vim.fn.jobstart(shell, { term = true, cwd = cwd })
    end
    vim.cmd("startinsert")
  else
    vim.api.nvim_win_hide(state.win)
  end
end

return M
