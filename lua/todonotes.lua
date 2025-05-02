local M = {}

local notes_buf = nil
local notes_win = nil

-- Hash function (SHA1, using Neovim's sha256 for simplicity)
local function hash(str)
  -- Use Neovim's sha256 and take first 16 chars for brevity
  return vim.fn.sha256(str):sub(1, 16)
end

-- Find project root (git or cwd)
local function get_project_root()
  local cwd = vim.fn.getcwd()
  local git_root = vim.fn.systemlist('git -C ' .. vim.fn.shellescape(cwd) .. ' rev-parse --show-toplevel')[1]
  if git_root and git_root ~= '' then
    return git_root
  else
    return cwd
  end
end

-- Path to notes file for this project (Harpoon-style)
local function get_notes_path()
  local root = get_project_root()
  local hash_str = hash(root)
  local dir = vim.fn.stdpath("data") .. "/todonotes"
  -- Ensure directory exists
  vim.fn.mkdir(dir, "p")
  return dir .. "/" .. hash_str .. ".md"
end

-- Load notes from file
local function load_notes()
  local notes_path = get_notes_path()
  local lines = {}
  local f = io.open(notes_path, "r")
  if f then
    for line in f:lines() do
      table.insert(lines, line)
    end
    f:close()
  end
  if #lines == 0 then
    lines = { "-- TODO Notes --", "- [ ] " }
  end
  return lines
end

-- Save notes to file
local function save_notes()
  if not notes_buf or not vim.api.nvim_buf_is_valid(notes_buf) then return end
  local lines = vim.api.nvim_buf_get_lines(notes_buf, 0, -1, false)
  local f = io.open(get_notes_path(), "w")
  if f then
    for _, line in ipairs(lines) do
      f:write(line .. "\n")
    end
    f:close()
  end
end

-- Insert checklist prefix on new lines in insert mode
local function setup_checklist_autocmd()
  vim.keymap.set("i", "<CR>", function()
    local pos = vim.api.nvim_win_get_cursor(0)
    local row = pos[1]
    -- Insert a new checklist item below
    vim.api.nvim_buf_set_lines(notes_buf, row, row, false, { "- [ ] " })
    -- Move cursor to after '- [ ] ' on the new line (column 6, 0-based)
    vim.api.nvim_win_set_cursor(0, { row + 1, 6 })
  end, { buffer = notes_buf })
end

function M.open_notes()
  if notes_win and vim.api.nvim_win_is_valid(notes_win) then
    vim.api.nvim_set_current_win(notes_win)
    return
  end

  if not notes_buf or not vim.api.nvim_buf_is_valid(notes_buf) then
    notes_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(notes_buf, "todonotes")
    vim.api.nvim_buf_set_option(notes_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(notes_buf, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(notes_buf, "swapfile", false)
    vim.api.nvim_buf_set_option(notes_buf, "filetype", "todonotes")
    vim.api.nvim_buf_set_lines(notes_buf, 0, -1, false, load_notes())
    setup_checklist_autocmd()
  end

  local width = math.floor(vim.o.columns * 0.5)
  local height = math.floor(vim.o.lines * 0.4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  notes_win = vim.api.nvim_open_win(notes_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = "todonotes",
    title_pos = "left",
  })

  vim.wo[notes_win].number = false
  vim.wo[notes_win].relativenumber = false
  vim.wo[notes_win].wrap = true

  -- <Esc>: Save and close
  vim.keymap.set("n", "<Esc>", function()
    save_notes()
    M.close_notes()
  end, { buffer = notes_buf, nowait = true })
  -- Intercept :w in the todo buffer to save and close
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = notes_buf,
    callback = function()
      save_notes()
      M.close_notes()
    end,
  })

  -- Optional: :Write command
  vim.api.nvim_buf_create_user_command(notes_buf, "Write", function()
    save_notes()
    M.close_notes()
  end, { bang = true })

  -- <Space>: Mark as done and move to bottom
  vim.keymap.set("n", "<Space>", function()
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local lines = vim.api.nvim_buf_get_lines(notes_buf, 0, -1, false)
    local line = lines[row + 1]
    if not line then return end

    if line:match("^%- %[ %]") then
      local done_line = line:gsub("%- %[ %]", "- [x]")
      table.remove(lines, row + 1)
      local insert_at = #lines
      for i = #lines, 1, -1 do
        if lines[i]:match("^%- %[x%]") then
          insert_at = i
          break
        end
      end
      table.insert(lines, insert_at + 1, done_line)
      vim.api.nvim_buf_set_lines(notes_buf, 0, -1, false, lines)
      local next_row = math.min(row + 1, #lines - 1)
      vim.api.nvim_win_set_cursor(0, { next_row + 1, 0 })
    end
  end, { buffer = notes_buf, nowait = true })

  -- 'o' in normal mode: add new checklist item below and enter insert mode
  vim.keymap.set("n", "o", function()
    local cur = vim.api.nvim_win_get_cursor(0)
    local row = cur[1]
    vim.api.nvim_buf_set_lines(notes_buf, row, row, false, { "- [ ] " })
    -- Move cursor to after '- [ ] ' on the new line (column 6, 0-based)
    vim.api.nvim_win_set_cursor(0, { row + 1, 6 })
    vim.cmd("startinsert")
  end, { buffer = notes_buf })

  -- Decide mode and cursor position
  local lines = vim.api.nvim_buf_get_lines(notes_buf, 0, -1, false)
  local first_item = nil
  for i, line in ipairs(lines) do
    if line:match("^%- %[ %]") then
      first_item = i
      break
    end
  end

  if #lines == 2 and lines[2] == "- [ ] " then
    -- Only the initial item: go to insert mode at end of line
    vim.api.nvim_win_set_cursor(notes_win, {2, #lines[2]})
    vim.cmd("startinsert")
  elseif first_item then
    -- Go to first unchecked item in normal mode
    vim.api.nvim_win_set_cursor(notes_win, {first_item, 0})
    vim.cmd("stopinsert")
  else
    -- Fallback: top of buffer
    vim.api.nvim_win_set_cursor(notes_win, {1, 0})
    vim.cmd("stopinsert")
  end
end

function M.close_notes()
  if notes_win and vim.api.nvim_win_is_valid(notes_win) then
    vim.api.nvim_win_close(notes_win, true)
    notes_win = nil
  end
end

function M.toggle_notes()
  if notes_win and vim.api.nvim_win_is_valid(notes_win) then
    M.close_notes()
  else
    M.open_notes()
  end
end

return M

