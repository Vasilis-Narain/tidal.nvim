local M = {}

local function norm_path(p)
  if vim.fn.has("win32") == 1 then
    return (p:gsub("\\", "/"):gsub("/+$", "")):lower()
  end
  return p:gsub("/+$", "")
end

local function project_dir_for(cwd)
  local home = vim.uv.os_homedir()
  local encoded = cwd:gsub("[^%w%-]", "-")
  return vim.fs.joinpath(home, ".claude", "projects", encoded)
end

local function relative_time(mtime)
  local diff = os.time() - mtime
  if diff < 60    then return diff .. "s ago" end
  if diff < 3600  then return math.floor(diff / 60) .. "m ago" end
  if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
  return math.floor(diff / 86400) .. "d ago"
end

local function extract_session_label(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local first_user, custom_title
  for line in f:lines() do
    local ok, entry = pcall(vim.json.decode, line)
    if ok and type(entry) == "table" then
      if entry.type == "custom-title" and type(entry.customTitle) == "string" then
        custom_title = entry.customTitle
      elseif not first_user and entry.type == "user" then
        local msg = entry.message
        if type(msg) == "table" and type(msg.content) == "string" then
          local c = msg.content
          if not c:match("^<command%-")
              and not c:match("^<local%-command%-")
              and not c:match("^Caveat:") then
            first_user = c:gsub("[\r\n]+", " ")
          end
        end
      end
    end
  end
  f:close()
  return custom_title or first_user
end

local function read_jsonl_tail(path, max_bytes)
  max_bytes = max_bytes or (256 * 1024)
  local stat = vim.uv.fs_stat(path)
  if not stat then return {} end
  local f = io.open(path, "rb")
  if not f then return {} end
  local data
  if stat.size <= max_bytes then
    data = f:read("*a")
  else
    f:seek("end", -max_bytes)
    data = f:read("*a")
    local nl = data:find("\n")
    if nl then data = data:sub(nl + 1) end
  end
  f:close()
  local entries = {}
  for line in (data or ""):gmatch("[^\r\n]+") do
    local ok, e = pcall(vim.json.decode, line)
    if ok and type(e) == "table" then table.insert(entries, e) end
  end
  return entries
end

local function format_transcript(entries, max_lines)
  local items = {}
  local total_lines = 0
  for i = #entries, 1, -1 do
    local e = entries[i]
    local role, text
    if e.type == "user" and type(e.message) == "table"
        and type(e.message.content) == "string" then
      local c = e.message.content
      if not c:match("^<command%-")
          and not c:match("^<local%-command%-")
          and not c:match("^Caveat:") then
        role, text = "user", c
      end
    elseif e.type == "assistant" and type(e.message) == "table"
        and type(e.message.content) == "table" then
      local parts = {}
      for _, blk in ipairs(e.message.content) do
        if type(blk) == "table" and blk.type == "text"
            and type(blk.text) == "string" then
          table.insert(parts, blk.text)
        end
      end
      if #parts > 0 then role, text = "assistant", table.concat(parts, "\n") end
    end
    if role then
      table.insert(items, 1, { role = role, text = text })
      local _, n = text:gsub("\n", "\n")
      total_lines = total_lines + n + 3
      if total_lines >= max_lines then break end
    end
  end
  local lines = {}
  for _, it in ipairs(items) do
    if it.role == "user" then
      table.insert(lines, "")
      table.insert(lines, "> " .. (it.text:gsub("\n", " ⏎ ")))
    else
      table.insert(lines, "")
      table.insert(lines, "⏺  Claude")
      table.insert(lines, "")
      for s in (it.text .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, "  " .. s)
      end
    end
  end
  if #lines == 0 then lines = { "(empty)" } end
  return lines
end

local function scan_dir_sessions(dir, source_cwd, sessions, seen)
  local stat = vim.uv.fs_stat(dir)
  if not stat or stat.type ~= "directory" then return end
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return end
  while true do
    local name, t = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if t == "file" and name:match("%.jsonl$") then
      local id = name:gsub("%.jsonl$", "")
      if not seen[id] then
        local path = vim.fs.joinpath(dir, name)
        local s = vim.uv.fs_stat(path)
        if s then
          local preview = extract_session_label(path) or "(no title)"
          if #preview > 80 then preview = preview:sub(1, 77) .. "..." end
          seen[id] = true
          table.insert(sessions, {
            id      = id,
            mtime   = s.mtime.sec,
            preview = preview,
            path    = path,
            cwd     = source_cwd,
          })
        end
      end
    end
  end
end

local function order_file_path(picker_cwd)
  return vim.fs.joinpath(project_dir_for(picker_cwd), ".tidal-order.json")
end

local function read_order(picker_cwd)
  local path = order_file_path(picker_cwd)
  local f = io.open(path, "r")
  if not f then return {} end
  local data = f:read("*a") or ""
  f:close()
  local ok, decoded = pcall(vim.json.decode, data)
  if ok and type(decoded) == "table" and type(decoded.order) == "table" then
    local out = {}
    for _, id in ipairs(decoded.order) do
      if type(id) == "string" then table.insert(out, id) end
    end
    return out
  end
  return {}
end

local function write_order(picker_cwd, order)
  local dir = project_dir_for(picker_cwd)
  if not vim.uv.fs_stat(dir) then return false end
  local path = order_file_path(picker_cwd)
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(vim.json.encode({ order = order }))
  f:close()
  local ok, err = os.rename(tmp, path)
  if not ok then
    pcall(os.remove, tmp)
    vim.notify("tidal: order write failed: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

local function apply_order(sessions, order)
  local pos = {}
  for i, id in ipairs(order) do pos[id] = i end
  local ordered, unordered = {}, {}
  for _, s in ipairs(sessions) do
    if pos[s.id] then table.insert(ordered, s) else table.insert(unordered, s) end
  end
  table.sort(ordered,   function(a, b) return pos[a.id] < pos[b.id] end)
  table.sort(unordered, function(a, b) return a.mtime > b.mtime end)
  local merged = {}
  for _, s in ipairs(ordered)   do table.insert(merged, s) end
  for _, s in ipairs(unordered) do table.insert(merged, s) end
  return merged
end

local function list_sessions(cwd, picker_cwd)
  local cfg = require("tidal.config").options.sessions
  local sessions, seen = {}, {}
  local root = norm_path(vim.uv.cwd() or cwd)
  local dir = cwd
  while dir and dir ~= "" do
    scan_dir_sessions(project_dir_for(dir), dir, sessions, seen)
    local norm = norm_path(dir)
    if norm == root then break end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then break end
    dir = parent
  end
  local order = read_order(picker_cwd or cwd)
  sessions = apply_order(sessions, order)
  if #sessions > cfg.max then
    for i = #sessions, cfg.max + 1, -1 do sessions[i] = nil end
  end
  return sessions
end

function M.move_chat(picker_cwd, id, direction)
  if direction ~= 1 and direction ~= -1 then return false end
  local sessions = list_sessions(picker_cwd, picker_cwd)
  local idx
  for i, s in ipairs(sessions) do
    if s.id == id then idx = i; break end
  end
  if not idx then return false end
  local target = idx + direction
  if target < 1 or target > #sessions then return false end
  sessions[idx], sessions[target] = sessions[target], sessions[idx]
  local new_order = {}
  for _, s in ipairs(sessions) do table.insert(new_order, s.id) end
  return write_order(picker_cwd, new_order)
end

function M.prune_order(picker_cwd, id)
  local order = read_order(picker_cwd)
  local changed, new_order = false, {}
  for _, oid in ipairs(order) do
    if oid == id then changed = true else table.insert(new_order, oid) end
  end
  if changed then write_order(picker_cwd, new_order) end
end

function M.landing(after_select)
  local cfg      = require("tidal.config").options
  local claude   = require("tidal.claude")
  local cwd      = vim.api.nvim_buf_get_name(0)
  if cwd == "" then cwd = vim.uv.cwd() else cwd = vim.fn.fnamemodify(cwd, ":p:h") end
  local picker_cwd = cwd

  local function build_entries()
    local sessions = list_sessions(cwd, picker_cwd)
    local out = { { id = nil, label = "[ New chat ]", preview = "[ New chat ]" } }
    for _, s in ipairs(sessions) do
      table.insert(out, {
        id      = s.id,
        label   = string.format("%-10s  %s", relative_time(s.mtime), s.preview),
        preview = s.preview,
        path    = s.path,
        cwd     = s.cwd,
      })
    end
    return out
  end

  local pickers      = require("telescope.pickers")
  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers   = require("telescope.previewers")
  require("telescope.config").values.dynamic_preview_title = true

  local ns = vim.api.nvim_create_namespace("tidal_transcript")
  vim.api.nvim_set_hl(0, "TidalUser",      cfg.highlights.user)
  vim.api.nvim_set_hl(0, "TidalUserBody",  cfg.highlights.user_body)
  vim.api.nvim_set_hl(0, "TidalAssistant", cfg.highlights.assistant)
  vim.api.nvim_set_hl(0, "TidalBody",      cfg.highlights.body)

  local nvim_root = norm_path(vim.uv.cwd() or cwd)
  local function rel_label(p)
    if not p then return " ./" end
    local n = norm_path(p)
    if n == nvim_root then return " ./" end
    if n:sub(1, #nvim_root + 1) == nvim_root .. "/" then
      return " ./" .. n:sub(#nvim_root + 2) .. "/"
    end
    return " " .. n .. "/"
  end

  local transcript_previewer = previewers.new_buffer_previewer({
    title     = "Transcript",
    dyn_title = function(_, entry)
      local sel = entry.value
      if not sel.id then return "New chat" end
      return "Transcript — " .. rel_label(sel.cwd)
    end,
    define_preview = function(self, entry, _)
      local sel   = entry.value
      local bufnr = self.state.bufnr
      if not sel.id then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          "", "  Start a new Claude session in:", "  " .. cwd,
        })
        return
      end
      local path    = sel.path or vim.fs.joinpath(project_dir_for(cwd), sel.id .. ".jsonl")
      local jentries = read_jsonl_tail(path, cfg.sessions.max_bytes)
      local h       = vim.api.nvim_win_get_height(self.state.winid)
      local lines   = format_transcript(jentries, h)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.bo[bufnr].filetype = "markdown"
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      local in_assistant = false
      for i, ln in ipairs(lines) do
        if ln:match("^⏺%s+Claude") then
          vim.api.nvim_buf_add_highlight(bufnr, ns, "TidalAssistant", i - 1, 0, -1)
          in_assistant = true
        elseif ln:match("^> ") then
          vim.api.nvim_buf_add_highlight(bufnr, ns, "TidalUser",     i - 1, 0, 2)
          vim.api.nvim_buf_add_highlight(bufnr, ns, "TidalUserBody", i - 1, 2, -1)
          in_assistant = false
        elseif in_assistant and ln:match("^  ") then
          vim.api.nvim_buf_add_highlight(bufnr, ns, "TidalBody", i - 1, 0, -1)
        end
      end
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(self.state.winid) then
          local last = math.max(1, vim.api.nvim_buf_line_count(bufnr))
          pcall(vim.api.nvim_win_set_cursor, self.state.winid, { last, 0 })
        end
      end)
    end,
  })

  local entry_maker = function(e)
    return { value = e, display = e.label, ordinal = e.label }
  end

  local layout_opts = {
    previewer       = transcript_previewer,
    layout_strategy = "horizontal",
    layout_config   = {
      width          = 0.85,
      height         = 0.7,
      prompt_position = "bottom",
      preview_width  = 0.6,
    },
    sorting_strategy = "descending",
    border           = true,
    borderchars      = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
  }

  local open
  local function make_attach(entries)
    return function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local sel = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if sel then
          claude.state.selection = { id = sel.value.id, cwd = sel.value.cwd }
          if vim.api.nvim_win_is_valid(claude.state.win) then
            vim.api.nvim_win_hide(claude.state.win)
            claude.state.win = -1
          end
          if vim.api.nvim_buf_is_valid(claude.state.buf) then
            pcall(vim.api.nvim_buf_delete, claude.state.buf, { force = true })
          end
          claude.state.buf = -1
          if after_select then
            vim.schedule(function()
              after_select()
              vim.cmd("startinsert")
            end)
          end
        end
      end)

      local function delete_selected()
        local sel = action_state.get_selected_entry()
        if not sel or not sel.value or not sel.value.id or not sel.value.path then
          return
        end
        if not sel.value.path:match("%.jsonl$") then
          vim.notify("tidal: refusing to delete non-jsonl path", vim.log.levels.ERROR)
          return
        end
        local choice = vim.fn.confirm("Delete chat?\n" .. (sel.value.preview or ""), "&Yes\n&No", 2)
        if choice ~= 1 then return end
        if vim.fn.delete(sel.value.path) ~= 0 then
          vim.notify("tidal: delete failed: " .. sel.value.path, vim.log.levels.ERROR)
          return
        end
        if claude.state.selection and claude.state.selection.id == sel.value.id then
          claude.state.selection = nil
        end
        M.prune_order(picker_cwd, sel.value.id)
        local del_idx
        for i, e in ipairs(entries) do
          if e.id == sel.value.id then del_idx = i; break end
        end
        local mode = vim.fn.mode() == "n" and "normal" or "insert"
        actions.close(prompt_bufnr)
        open({ index = del_idx, mode = mode })
      end

      local function make_move(direction)
        return function()
          local sel = action_state.get_selected_entry()
          if not sel or not sel.value or not sel.value.id then return end
          if not M.move_chat(picker_cwd, sel.value.id, direction) then return end
          local mode = vim.fn.mode() == "n" and "normal" or "insert"
          actions.close(prompt_bufnr)
          open({ focus_id = sel.value.id, mode = mode })
        end
      end

      local delkey  = cfg.sessions.delete_key
      local upkey   = cfg.sessions.move_up_key
      local downkey = cfg.sessions.move_down_key
      if delkey and delkey ~= "" then
        map("i", delkey, delete_selected)
        map("n", delkey, delete_selected)
      end
      if upkey and upkey ~= "" then
        map("i", upkey, make_move(-1))
        map("n", upkey, make_move(-1))
      end
      if downkey and downkey ~= "" then
        map("i", downkey, make_move(1))
        map("n", downkey, make_move(1))
      end
      return true
    end
  end

  open = function(restore)
    local entries = build_entries()
    local target_index
    if type(restore) == "table" then
      if restore.focus_id then
        for i, e in ipairs(entries) do
          if e.id == restore.focus_id then target_index = i; break end
        end
      elseif restore.index then
        target_index = math.min(restore.index, #entries)
      end
    end
    pickers.new(layout_opts, {
      prompt_title            = "Claude sessions",
      default_selection_index = target_index,
      initial_mode            = (type(restore) == "table" and restore.mode) or "insert",
      finder                  = finders.new_table({
        results     = entries,
        entry_maker = entry_maker,
      }),
      sorter          = conf.generic_sorter({}),
      attach_mappings = make_attach(entries),
    }):find()
  end

  open()
end

return M
