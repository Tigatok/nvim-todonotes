# todonotes.nvim

A simple, fast, project-aware floating TODO checklist for Neovim.

- 🗂️ **Per-project**: Each project gets its own checklist, stored in `~/.local/share/todonotes/`
- 📝 **Always a checklist**: Every line is a markdown checklist item (`- [ ]`)
- ⚡ **Fast workflow**: Open, add, check off, and close with minimal keystrokes
- 🪟 **Floating window**: Opens in a centered, titled floating window

---

## ✨ Features

- **Per-project** persistent todo lists (Harpoon-style storage)
- **Floating window** with a border and title
- **Markdown checklist**: Every line is always a `- [ ]` item
- **Quick add**: `o`/`O` to add new items below/above
- **Check off**: `<Space>` in normal mode marks an item as done and moves it to the bottom
- **Smart insert**: All text entry happens after the checkbox
- **Auto-fix**: No empty lines, ever
- **Easy close**: `<Esc>` or `:w` to save and close

---

## 🚀 Installation

**With [lazy.nvim](https://github.com/folke/lazy.nvim):**

```lua
{
  "yourusername/nvim-todonotes",
  config = function()
    local todonotes = require("todonotes")
    vim.keymap.set("n", "<leader>tt", function()
      todonotes.toggle_notes()
    end, { desc = "Toggle Todo Notes" })
  end,
}
```
