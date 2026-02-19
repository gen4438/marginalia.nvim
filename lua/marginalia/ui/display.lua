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
local ns_id = vim.api.nvim_create_namespace("marginalia_manager")
local extmark_to_ann_id = {}

local function normalize_for_manager_line(value)
  local text = tostring(value or "")
  text = text:gsub("\r\n", "\\n")
  text = text:gsub("[\r\n]", "\\n")
  return text
end

---Read extmarks to get the current ordered annotation IDs from the buffer
---@return string[]
local function get_ordered_ids()
  if not manage_buf or not vim.api.nvim_buf_is_valid(manage_buf) then
    return {}
  end

  local extmarks = vim.api.nvim_buf_get_extmarks(manage_buf, ns_id, 0, -1, {})
  local ordered_ids = {}
  for _, ext in ipairs(extmarks) do
    local ann_id = extmark_to_ann_id[ext[1]]
    if ann_id then
      table.insert(ordered_ids, ann_id)
    end
  end
  return ordered_ids
end

---Sync buffer state (order + deletions) back to store
local function sync_manager()
  local ordered_ids = get_ordered_ids()
  store.reorder(ordered_ids)
  store.save()
end

---Get the annotation item at the current cursor line
---@return table|nil
local function get_annotation_at_cursor()
  if not manage_buf or not vim.api.nvim_buf_is_valid(manage_buf) then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1 -- 0-indexed

  local extmarks = vim.api.nvim_buf_get_extmarks(manage_buf, ns_id, { line, 0 }, { line, -1 }, {})
  if #extmarks == 0 then
    return nil
  end

  local ann_id = extmark_to_ann_id[extmarks[1][1]]
  if not ann_id then
    return nil
  end

  return store.get(ann_id)
end

local function close_manager()
  if manage_buf and vim.api.nvim_buf_is_valid(manage_buf) then
    sync_manager()
    vim.cmd("bwipeout " .. manage_buf)
  end
  manage_buf = nil
  extmark_to_ann_id = {}
end

---Render management buffer content
function M.render_manager()
  if not manage_buf or not vim.api.nvim_buf_is_valid(manage_buf) then
    return
  end

  local items = store.list() or {}
  local lines = {}
  local ann_lines = {} -- { line_idx (1-based), ann_id }

  table.insert(lines, "# Marginalia Manager (<CR>: open, q: save & close)")
  table.insert(lines, string.rep("-", 50))

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
    table.insert(ann_lines, { line_idx, item.id })
  end

  vim.api.nvim_buf_set_lines(manage_buf, 0, -1, false, lines)

  -- Set extmarks on annotation lines to track through edits
  vim.api.nvim_buf_clear_namespace(manage_buf, ns_id, 0, -1)
  extmark_to_ann_id = {}
  for _, pair in ipairs(ann_lines) do
    local ext_id = vim.api.nvim_buf_set_extmark(manage_buf, ns_id, pair[1] - 1, 0, {})
    extmark_to_ann_id[ext_id] = pair[2]
  end
end

---Open interactive management buffer
function M.open_manager()
  if manage_buf and vim.api.nvim_buf_is_valid(manage_buf) then
    local wins = vim.fn.win_findbuf(manage_buf)
    if #wins > 0 then
      vim.api.nvim_set_current_win(wins[1])
    else
      vim.cmd("buffer " .. manage_buf)
    end
    M.render_manager()
    return
  end

  -- Create new buffer
  manage_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(manage_buf, "MarginaliaManager")
  vim.api.nvim_buf_set_option(manage_buf, "filetype", "marginalia")
  vim.api.nvim_buf_set_option(manage_buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(manage_buf, "swapfile", false)

  M.render_manager()

  vim.cmd("buffer " .. manage_buf)

  -- Keymaps (only <CR> and q - everything else is native vim)
  local opts = { noremap = true, silent = true, buffer = manage_buf }

  vim.keymap.set("n", "<CR>", function()
    local item = get_annotation_at_cursor()
    if not item then
      print("No annotation on this line.")
      return
    end

    local file = item.file
    local project = require("marginalia.utils.project")
    local root = project.root()
    if root then
      file = root .. "/" .. file
    end

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
  end, opts)

  vim.keymap.set("n", "q", function()
    close_manager()
  end, opts)

  -- BufWriteCmd: :w syncs to store without closing
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = manage_buf,
    callback = function()
      sync_manager()
      vim.api.nvim_buf_set_option(manage_buf, "modified", false)
      print("Marginalia: Annotations synced.")
    end,
  })
end

return M
