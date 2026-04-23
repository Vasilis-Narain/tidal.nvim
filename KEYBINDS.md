# Keybinds

All keys below are configurable via `setup()`. Set a key to `false` or `""` to disable it.

## Global (normal mode)

| Key | Action | Config key |
|-----|--------|-----------|
| `<leader>tt` | Toggle floating terminal | `keymaps.toggle_terminal` |
| `<leader>tc` | Toggle Claude split (33% width) | `keymaps.toggle_claude` |
| `<leader>tC` | Toggle Claude split (50% width) | `keymaps.toggle_claude_big` |
| `<leader>tlc` | Open Claude session picker | `keymaps.claude_pick` |

Disable all four with `setup({ keymaps = {} })`.

## Claude split (terminal mode)

| Key | Action | Config key |
|-----|--------|-----------|
| `<Esc>` | Leave terminal mode (standard Neovim `<C-\><C-n>`) | not configurable |
| `<C-q>` | Send `<Esc>` to Claude (cancel prompts / close menus without leaving terminal mode) | `claude.escape` |

Rebind or disable `<C-q>`:

```lua
require("tidal").setup({
  claude = { escape = "<C-g>" }, -- or escape = false to disable
})
```

## Session picker

Active inside the Telescope picker opened by `<leader>tlc` (`:TidalPick`).

| Key | Action | Config key |
|-----|--------|-----------|
| `<M-d>` | Delete chat under cursor — removes the `.jsonl` from disk and refreshes the picker | `sessions.delete_key` |
| `<C-d>` | Move highlighted chat **down** one slot | `sessions.move_down_key` |
| `<C-u>` | Move highlighted chat **up** one slot | `sessions.move_up_key` |

Chat order persists across Neovim sessions in `.tidal-order.json` next to the chat files.

Disabling `move_up_key` / `move_down_key` restores Telescope's default preview-scroll mappings on `<C-u>` / `<C-d>`.

```lua
require("tidal").setup({
  sessions = {
    delete_key    = "<C-x>",
    move_up_key   = false,
    move_down_key = false,
  },
})
```

## Defaults summary

```lua
require("tidal").setup({
  claude = {
    escape = "<C-q>",
  },
  sessions = {
    delete_key    = "<M-d>",
    move_up_key   = "<C-d>",
    move_down_key = "<C-u>",
  },
  keymaps = {
    toggle_terminal   = "<leader>tt",
    toggle_claude     = "<leader>tc",
    toggle_claude_big = "<leader>tC",
    claude_pick       = "<leader>tlc",
  },
})
```
