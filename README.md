# tidal.nvim

Minimal Floating terminal + Claude code session split for Neovim.

![Screenshot of Claude session picker](/img/picker.png)
![Screenshot of Claude in Vertical Split](/img/v_split.png)
![Screenshot of Floating Terminal](/img/floaterminal.png)

## Features

- **Floating terminal** — toggle a centered floating window with your shell
- **Claude split** — open Claude CLI in a side split, persisted across toggles
- **Session picker** — Telescope-based picker for Claude chat history with live transcript preview

## Requirements

- Neovim 0.10+
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [Claude CLI](https://claude.ai/code) (for the Claude split)

## Install

```lua
-- lazy.nvim
{
  "Vasilis-Narain/tidal.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("tidal").setup()
  end,
}
```

## Setup

Call `setup()` once. All options are optional — defaults apply if omitted.

```lua
require("tidal").setup({
  terminal = {
    shell  = nil,       -- nil = auto-detect (Git bash on Windows, $SHELL elsewhere)
    width  = 0.8,
    height = 0.8,
    border = "rounded",
  },
  claude = {
    cmd        = "claude",   -- path to Claude CLI binary
    fraction   = 0.33,       -- default split width
    statusline = " Claude",
    escape     = "<C-q>",    -- terminal-mode key that sends <Esc> to Claude (set false/"" to disable)
  },
  sessions = {
    max           = 20,
    max_bytes     = 262144,
    delete_key    = "<M-d>",     -- in picker: delete chat .jsonl under cursor (set false/"" to disable)
    move_up_key   = "<C-d>",     -- in picker: move chat up (set false/"" to disable)
    move_down_key = "<C-u>",     -- in picker: move chat down (set false/"" to disable)
  },
  highlights = {
    user      = { fg = "#7aa2f7", bold = true },    -- blue
    user_body = { fg = "#bb9af7", italic = true },  -- purple
    assistant = { fg = "#e0af68", bold = true },    -- orange
    body      = { fg = "#c0caf5" },                 -- soft white
  },
  keymaps = {
    toggle_terminal   = "<leader>tt",
    toggle_claude     = "<leader>tc",
    toggle_claude_big = "<leader>tC",
    claude_pick       = "<leader>tlc",
  },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:Tidal` | Toggle floating terminal |
| `:TidalClaude` | Toggle Claude side split |
| `:TidalPick` | Open Claude session picker |

## Keymaps

| Key | Action |
|-----|--------|
| `<leader>tt` | Toggle floating terminal |
| `<leader>tc` | Toggle Claude split (33% width) |
| `<leader>tC` | Toggle Claude split (50% width) |
| `<leader>tlc` | Claude session picker |
| `<C-q>` | Inside Claude split: send `<Esc>` to Claude |
| `<M-d>` | Inside session picker: delete chat under cursor |
| `<C-d>` / `<C-u>` | Inside session picker: move chat down / up |

See [KEYBINDS.md](KEYBINDS.md) for the full list, defaults, and rebind/disable examples.

## Highlights

| Group | Default | Description |
|-------|---------|-------------|
| `TidalUser` | `Title` | User message prefix |
| `TidalUserBody` | `Comment` | User message body |
| `TidalAssistant` | `Special` | Assistant header |
| `TidalBody` | `Normal` | Assistant body text |

## Windows

On Windows, tidal.nvim auto-detects Git bash at `C:\Program Files\Git\bin\bash.exe`.
To use a different shell, set `terminal.shell` in your config:

```lua
require("tidal").setup({
  terminal = { shell = { "pwsh", "-NoLogo" } },
})
```

## Security notes

- `claude.cmd` is executed as argv[0] via `jobstart` (resolved through `$PATH`). Only set it to a binary you trust — a malicious `cmd` value pasted from an untrusted config runs arbitrary code on toggle.
- `terminal.shell` is executed the same way. Same trust boundary applies.
- The session picker reads and deletes `.jsonl` files under `~/.claude/projects/<encoded-cwd>/`. The delete action rejects symlinks and paths outside the project dir, and the resume flow rejects session ids that are not UUID-shaped, so a malicious file dropped into that directory cannot smuggle CLI flags or redirect deletes.

## License

MIT
