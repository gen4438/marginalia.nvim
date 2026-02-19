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
local line_to_item = {}

local function close_manager()
  if manage_buf and vim.api.nvim_buf_is_valid(manage_buf) then
    vim.cmd("bwipeout " .. manage_buf)
  end
  manage_buf = nil
  line_to_id = {}
  line_to_item = {}
end

local function normalize_for_manager_line(value)
  local text = tostring(value or "")
  text = text:gsub("\r\n", "\\n")
  text = text:gsub("[\r\n]", "\\n")
  return text
end

---Render management buffer content
function M.render_manager()
  if not manage_buf or not vim.api.nvim_buf_is_valid(manage_buf) then
    return
  end

  local items = store.list() or {}
  local lines = {}
  line_to_id = {}
  line_to_item = {}

  table.insert(lines, "# Marginalia Manager (dd: delete, r: refresh, <CR>: open)")
  table.insert(lines, string.rep("-", 40))

  for _, item in ipairs(items) do
    local line_idx = #lines + 1
    local start_line = tonumber(item.line) or 0
    local end_line = tonumber(item.end_line) or start_line
    local line_range
    if end_line > start_line then
      line_range = string.format("%d-%d", start_line, end_line)
    else
      line_range = tostring(start_line)
    end
    local text = string.format(
      "%s:%s | %s",
      normalize_for_manager_line(item.file),
      line_range,
      normalize_for_manager_line(item.comment)
    )
    table.insert(lines, text)
    line_to_id[line_idx] = item.id
    line_to_item[line_idx] = item
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

  vim.keymap.set("n", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local item = line_to_item[line]

    if item then
      local file = item.file
      local project = require("marginalia.utils.project")
      local root = project.root()
      if root then
        file = root .. "/" .. file
      end

      -- Close manager and open the file with visual selection
      local start_line = tonumber(item.line) or 1
      local end_line = tonumber(item.end_line) or start_line
      close_manager()
      vim.cmd("edit " .. vim.fn.fnameescape(file))
      pcall(function()
        vim.api.nvim_win_set_cursor(0, { start_line, 0 })
        vim.cmd("normal! V")
        if end_line > start_line then
          vim.api.nvim_win_set_cursor(0, { end_line, 0 })
        end
      end)
    else
      print("No annotation on this line.")
    end
  end, opts)

  vim.keymap.set("n", "q", function()
    close_manager()
  end, opts)
end

return M
