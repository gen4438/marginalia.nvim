local M = {}
local store = require("marginalia.core.store")
local generate = require("marginalia.core.generate")

local config = {
  textobject = "a",
}

---Configure display module
---@param opts table|nil
function M.setup(opts)
  opts = opts or {}
  if opts.textobject then
    config.textobject = opts.textobject
  end
end

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

---Check if a line is an annotation header by extmark presence
---@param lnum number 1-based line number
---@return boolean
local function is_header_line(lnum)
  if not manage_buf or not vim.api.nvim_buf_is_valid(manage_buf) then
    return false
  end
  local marks = vim.api.nvim_buf_get_extmarks(manage_buf, ns_id, { lnum - 1, 0 }, { lnum - 1, 0 }, {})
  return #marks > 0
end

---Build line_range string from annotation item
---@param item table
---@return string
local function format_line_range(item)
  local start_line = tonumber(item.line) or 0
  local end_line = tonumber(item.end_line) or start_line
  if end_line > start_line then
    return string.format("%d-%d", start_line, end_line)
  end
  return tostring(start_line)
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

  -- Search from buffer start to cursor line for the last extmark
  local extmarks = vim.api.nvim_buf_get_extmarks(manage_buf, ns_id, { 0, 0 }, { line, -1 }, {})
  if #extmarks == 0 then
    return nil
  end

  local last_ext = extmarks[#extmarks]
  local ann_id = extmark_to_ann_id[last_ext[1]]
  if not ann_id then
    return nil
  end

  return store.get(ann_id)
end

---Get the block range (1-based, inclusive) for the annotation containing lnum
---@param lnum number 1-based line number
---@return number|nil start_line 1-based
---@return number|nil end_line 1-based (content end, excluding trailing blank separator)
---@return number|nil block_end 1-based (including trailing blank separator)
local function get_block_range(lnum)
  if not manage_buf or not vim.api.nvim_buf_is_valid(manage_buf) then
    return nil, nil, nil
  end

  local total = vim.api.nvim_buf_line_count(manage_buf)
  local lines = vim.api.nvim_buf_get_lines(manage_buf, 0, -1, false)

  -- Find the header line at or above lnum (using extmarks)
  local start = nil
  for i = lnum, 1, -1 do
    if is_header_line(i) then
      start = i
      break
    end
  end
  if not start then
    return nil, nil, nil
  end

  -- Find end: line before next header or end of buffer
  local content_end = total
  local block_end = total
  for i = start + 1, total do
    if is_header_line(i) then
      content_end = i - 1
      block_end = i - 1
      -- Check if the line before the next header is a blank separator
      if content_end >= start + 1 and lines[content_end] == "" then
        content_end = content_end - 1
      end
      break
    end
  end

  -- Trim trailing blank at end of buffer
  if block_end == total and lines[total] == "" then
    content_end = total - 1
  end

  return start, content_end, block_end
end

---Find all header line numbers (1-based) using extmarks
---@return number[]
local function find_header_lines()
  if not manage_buf or not vim.api.nvim_buf_is_valid(manage_buf) then
    return {}
  end
  local extmarks = vim.api.nvim_buf_get_extmarks(manage_buf, ns_id, 0, -1, {})
  local headers = {}
  for _, ext in ipairs(extmarks) do
    table.insert(headers, ext[2] + 1) -- convert 0-indexed to 1-indexed
  end
  return headers
end

local function close_manager()
  if manage_buf and vim.api.nvim_buf_is_valid(manage_buf) then
    sync_manager()
    vim.cmd("bwipeout " .. manage_buf)
  end
  manage_buf = nil
  extmark_to_ann_id = {}
end

---Render management buffer content with multi-line annotation blocks
function M.render_manager()
  if not manage_buf or not vim.api.nvim_buf_is_valid(manage_buf) then
    return
  end

  local items = store.list() or {}
  local lines = {}
  local ann_lines = {} -- { line_idx (1-based), ann_id }

  table.insert(lines, "# Marginalia Manager (<CR>: open, q: save & close, za: toggle fold)")
  table.insert(lines, string.rep("-", 60))

  for idx, item in ipairs(items) do
    local block_start = #lines + 1

    -- Header line: @file#line_range
    local line_range = format_line_range(item)
    table.insert(lines, string.format("@%s#%s", item.file or "unknown", line_range))

    -- Code block (if code_chunk exists)
    local code = item.code_chunk or ""
    if code ~= "" then
      local ext = (item.file or ""):match("%.([%w_]+)$") or ""
      local lang = generate.ext_to_lang(ext)
      table.insert(lines, "```" .. lang)
      for _, code_line in ipairs(vim.split(code, "\n", { plain = true })) do
        table.insert(lines, code_line)
      end
      table.insert(lines, "```")
    end

    -- Comment lines
    local comment = item.comment or ""
    for _, comment_line in ipairs(vim.split(comment, "\n", { plain = true })) do
      table.insert(lines, comment_line)
    end

    -- Blank separator between blocks (except after last)
    if idx < #items then
      table.insert(lines, "")
    end

    table.insert(ann_lines, { block_start, item.id })
  end

  vim.api.nvim_buf_set_lines(manage_buf, 0, -1, false, lines)

  -- Set extmarks on annotation header lines to track through edits
  vim.api.nvim_buf_clear_namespace(manage_buf, ns_id, 0, -1)
  extmark_to_ann_id = {}
  for _, pair in ipairs(ann_lines) do
    local ext_id = vim.api.nvim_buf_set_extmark(manage_buf, ns_id, pair[1] - 1, 0, {})
    extmark_to_ann_id[ext_id] = pair[2]
  end
end

-- Fold expression for manager buffer
function _G.marginalia_foldexpr()
  local lnum = vim.v.lnum

  -- Header lines (lines 1-2) are never folded
  if lnum <= 2 then
    return "0"
  end

  -- Annotation block starts with extmark-tracked header
  if is_header_line(lnum) then
    return ">1"
  end

  local line = vim.fn.getline(lnum)

  -- Blank line is a block separator only if the next non-blank line is a header
  if line == "" then
    if lnum == vim.fn.line("$") then
      return "0"
    end
    if is_header_line(lnum + 1) then
      return "0"
    end
  end

  -- Everything else belongs to the current fold
  return "1"
end

-- Fold text for manager buffer: show summary line when folded
function _G.marginalia_foldtext()
  local foldstart = vim.v.foldstart
  local foldend = vim.v.foldend
  local lines = vim.api.nvim_buf_get_lines(0, foldstart - 1, foldend, false)

  -- First line is @file#line_range
  local header = lines[1] or ""
  local file, line_range = header:match("^@(.-)#(.+)$")
  if not file then
    return header
  end

  -- Collect comment lines (skip code fence sections)
  local comment_lines = {}
  local in_code_fence = false
  for i = 2, #lines do
    local l = lines[i]
    if l:match("^```") then
      in_code_fence = not in_code_fence
    elseif not in_code_fence and l ~= "" then
      table.insert(comment_lines, l)
    end
  end

  local comment_text = table.concat(comment_lines, "\\n")
  return string.format("%s:%s | %s", file, line_range, comment_text)
end

---Set up fold options for the manager window
local function setup_fold_options()
  vim.wo.foldmethod = "expr"
  vim.wo.foldexpr = "v:lua.marginalia_foldexpr()"
  vim.wo.foldtext = "v:lua.marginalia_foldtext()"
  vim.wo.foldlevel = 0
  vim.wo.foldenable = true
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
    setup_fold_options()
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

  -- Set fold options (window-local, must be set after buffer is displayed)
  setup_fold_options()

  local opts = { noremap = true, silent = true, buffer = manage_buf }

  -- <CR>: open annotated file
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

  -- q: save & close
  vim.keymap.set("n", "q", function()
    close_manager()
  end, opts)

  -- dd: block-aware delete (only when cursor is on a header line)
  vim.keymap.set("n", "dd", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local lnum = cursor[1]

    if is_header_line(lnum) then
      local start, _, block_end = get_block_range(lnum)
      if start and block_end then
        -- Remove the extmark so sync_manager won't include this annotation
        local marks = vim.api.nvim_buf_get_extmarks(manage_buf, ns_id, { start - 1, 0 }, { start - 1, 0 }, {})
        for _, mark in ipairs(marks) do
          extmark_to_ann_id[mark[1]] = nil
        end
        vim.api.nvim_buf_set_lines(manage_buf, start - 1, block_end, false, {})
      end
    else
      -- Normal dd for non-header lines (allow editing comments/code)
      vim.cmd('normal! "_dd')
    end
  end, opts)

  -- Text object: ia (inner annotation) and aa (a annotation)
  local function select_annotation(inner)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local lnum = cursor[1]
    local start, content_end, block_end = get_block_range(lnum)
    if not start then
      return
    end

    if inner then
      -- Inner: content lines after header (code + comment)
      local inner_start = start + 1
      if inner_start > content_end then
        return
      end
      vim.api.nvim_win_set_cursor(0, { inner_start, 0 })
      vim.cmd("normal! V")
      if content_end > inner_start then
        vim.api.nvim_win_set_cursor(0, { content_end, 0 })
      end
    else
      -- A annotation: whole block including trailing separator
      vim.api.nvim_win_set_cursor(0, { start, 0 })
      vim.cmd("normal! V")
      if block_end > start then
        vim.api.nvim_win_set_cursor(0, { block_end, 0 })
      end
    end
  end

  local c = config.textobject
  vim.keymap.set("o", "i" .. c, function()
    select_annotation(true)
  end, opts)
  vim.keymap.set("x", "i" .. c, function()
    select_annotation(true)
  end, opts)
  vim.keymap.set("o", "a" .. c, function()
    select_annotation(false)
  end, opts)
  vim.keymap.set("x", "a" .. c, function()
    select_annotation(false)
  end, opts)

  -- Block navigation: [c / ]c (configurable)
  vim.keymap.set("n", "]" .. c, function()
    local count = vim.v.count1
    local cursor = vim.api.nvim_win_get_cursor(0)
    local lnum = cursor[1]
    local headers = find_header_lines()
    local moved = 0
    for _, h in ipairs(headers) do
      if h > lnum then
        moved = moved + 1
        if moved == count then
          vim.api.nvim_win_set_cursor(0, { h, 0 })
          return
        end
      end
    end
  end, opts)

  vim.keymap.set("n", "[" .. c, function()
    local count = vim.v.count1
    local cursor = vim.api.nvim_win_get_cursor(0)
    local lnum = cursor[1]
    local headers = find_header_lines()
    local moved = 0
    for i = #headers, 1, -1 do
      if headers[i] < lnum then
        moved = moved + 1
        if moved == count then
          vim.api.nvim_win_set_cursor(0, { headers[i], 0 })
          return
        end
      end
    end
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
