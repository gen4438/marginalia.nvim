local M = {}
local ui = require("marginalia.ui.input")
local store = require("marginalia.core.store")
local project = require("marginalia.utils.project")
local generate = require("marginalia.core.generate")
local clipboard = require("marginalia.utils.clipboard")

local config = {}

---Configure capture module
---@param opts table|nil
function M.setup(opts)
  opts = opts or {}
  config.include_code = opts.include_code or false
end

---Prompt for annotation on the given line range and save
---@param start_line number
---@param end_line number
---@param runtime_opts table|nil
local function annotate_range(start_line, end_line, runtime_opts)
  runtime_opts = runtime_opts or {}
  local include_code = runtime_opts.include_code
  if include_code == nil then
    include_code = config.include_code
  end

  -- Get content
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local code_chunk = table.concat(lines, "\n")

  -- Get file path relative to project root
  local file = vim.fn.expand("%:p")
  if file == "" then
    file = vim.api.nvim_buf_get_name(0)
  end
  if file == "" then
    file = "[unsaved]"
  end
  local root = project.root()
  if root and file:sub(1, #root) == root then
    -- +2 to skip leading separator
    file = file:sub(#root + 2)
  end

  -- Open Input UI
  ui.open(function(input_lines)
    if not input_lines or #input_lines == 0 then
      return
    end

    -- Trim trailing blank lines
    while #input_lines > 0 and input_lines[#input_lines]:match("^%s*$") do
      table.remove(input_lines)
    end
    if #input_lines == 0 then
      return
    end

    -- Trim trailing whitespace from each line
    for i, l in ipairs(input_lines) do
      input_lines[i] = l:gsub("%s+$", "")
    end

    local comment = table.concat(input_lines, "\n")
    if comment:match("^%s*$") then
      return
    end

    local item = {
      file = file,
      line = start_line,
      end_line = end_line,
      code_chunk = code_chunk,
      comment = comment,
      timestamp = os.time(),
    }

    store.add(item)
    store.save()

    -- Generate Markdown and copy to clipboard
    local md = generate.markdown(item, { include_code = include_code })
    clipboard.copy(md)

    print("Marginalia: Annotation saved & copied to clipboard.")
  end)
end

---Process the current visual selection and prompt for annotation
---@param opts table|nil
function M.process_selection(opts)
  -- Get visual selection range
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Handle case where marks are invalid (e.g. not set yet)
  if start_line == 0 then
    print("No selection found.")
    return
  end

  -- Swap if needed
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  annotate_range(start_line, end_line, opts)
end

---Annotate the current cursor line
---@param opts table|nil
function M.process_line(opts)
  local line = vim.fn.line(".")
  annotate_range(line, line, opts)
end

return M
