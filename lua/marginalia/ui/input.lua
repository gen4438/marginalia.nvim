local M = {}

---Open floating input window
---@param callback function(lines: table) callback with entered text lines
---@param opts table|nil options for window (e.g. initial_content)
---@return table context {win_id, buf_id, submit, cancel}
function M.open(callback, opts)
  opts = opts or {}
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown") -- helpful for syntax

  -- Calculate dimensions (center)
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Add Annotation (<CR>: Save / q: Cancel) ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  if opts.initial_lines then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.initial_lines)
    -- Move cursor to top
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end

  -- Actions
  local function submit()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if callback then
      callback(lines)
    end
  end

  local function cancel()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Keymaps
  local map_opts = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set("n", "<CR>", submit, map_opts)
  vim.keymap.set("n", "q", cancel, map_opts)
  vim.keymap.set("n", "<Esc>", cancel, map_opts)

  -- Start in insert mode
  vim.cmd("startinsert")

  return {
    win_id = win,
    buf_id = buf,
    submit = submit,
    cancel = cancel,
  }
end

return M
