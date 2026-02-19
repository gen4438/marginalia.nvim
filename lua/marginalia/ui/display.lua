local M = {}
local store = require("marginalia.core.store")

---Populate and open quickfix list with annotations
function M.open_list()
  local items = store.list()
  if not items then
    items = {}
  end

  local qf_list = {}

  for _, item in ipairs(items) do
    table.insert(qf_list, {
      filename = item.file,
      lnum = item.line,
      text = item.comment,
      valid = 1,
      user_data = item,
    })
  end

  vim.fn.setqflist(qf_list, "r")
  vim.fn.setqflist({}, "a", { title = "Marginalia Annotations" })

  if #qf_list > 0 then
    vim.cmd("copen")
  else
    print("No annotations found.")
    vim.cmd("cclose")
  end
end

-- Management buffer state
local manage_buf = nil
local line_to_id = {}

---Render management buffer content
function M.render_manager()
  if not manage_buf or not vim.api.nvim_buf_is_valid(manage_buf) then
    return
  end

  local items = store.list() or {}
  local lines = {}
  line_to_id = {}

  table.insert(lines, "# Marginalia Manager (dd: delete, r: refresh)")
  table.insert(lines, string.rep("-", 40))

  for _, item in ipairs(items) do
    local line_idx = #lines + 1
    local text = string.format("%s:%d | %s", item.file, item.line, item.comment)
    table.insert(lines, text)
    line_to_id[line_idx] = item.id
  end

  vim.api.nvim_buf_set_option(manage_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(manage_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(manage_buf, "modifiable", false)
end

---Open interactive management buffer
function M.open_manager()
  if manage_buf and vim.api.nvim_buf_is_valid(manage_buf) then
    -- If window exists, jump to it
    local wins = vim.fn.win_findbuf(manage_buf)
    if #wins > 0 then
      vim.api.nvim_set_current_win(wins[1])
    else
      vim.cmd("buffer " .. manage_buf)
    end
    M.render_manager() -- Refresh content
    return
  end

  -- Create new buffer
  manage_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(manage_buf, "MarginaliaManager")
  vim.api.nvim_buf_set_option(manage_buf, "filetype", "marginalia")
  vim.api.nvim_buf_set_option(manage_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(manage_buf, "swapfile", false)

  M.render_manager()

  -- Open in split or current window?
  vim.cmd("buffer " .. manage_buf)

  -- Keymaps
  local opts = { noremap = true, silent = true, buffer = manage_buf }

  vim.keymap.set("n", "dd", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local id = line_to_id[line]

    if id then
      local success = store.remove(id)
      if success then
        store.save()
        M.render_manager()
        -- Attempt to keep cursor position
        pcall(vim.api.nvim_win_set_cursor, 0, { math.min(line, vim.api.nvim_buf_line_count(manage_buf)), 0 })
        print("Deleted annotation.")
      else
        print("Failed to delete annotation.")
      end
    else
      print("No annotation on this line.")
    end
  end, opts)

  vim.keymap.set("n", "r", function()
    M.render_manager()
    print("Refreshed.")
  end, opts)

  vim.keymap.set("n", "q", function()
    vim.cmd("bd " .. manage_buf)
  end, opts)
end

return M
