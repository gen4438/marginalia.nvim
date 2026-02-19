local M = {}
local ui = require("marginalia.ui.input")
local store = require("marginalia.core.store")
local project = require("marginalia.utils.project")
local generate = require("marginalia.core.generate")
local clipboard = require("marginalia.utils.clipboard")

---Process the current visual selection and prompt for annotation
function M.process_selection()
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

  -- Get content
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local code_chunk = table.concat(lines, "\n")

  -- Get file path relative to project root
  local file = vim.fn.expand("%:p")
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
    local md = generate.markdown(item)
    clipboard.copy(md)

    print("Marginalia: Annotation saved & copied to clipboard.")
  end)
end

return M
