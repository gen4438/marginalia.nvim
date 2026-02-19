local M = {}

---Generate markdown for an annotation item
---@param item table {file, line, end_line, code_chunk, comment, ...}
---@param opts table|nil {include_code=boolean}
---@return string markdown content
function M.markdown(item, opts)
  opts = opts or {}
  local file = item.file or "unknown"
  local ext = file:match("%.([%w_]+)$") or ""
  local lang = ext

  -- Simple mapping for common extensions
  if lang == "rs" then
    lang = "rust"
  end
  if lang == "ts" then
    lang = "typescript"
  end
  if lang == "js" then
    lang = "javascript"
  end
  if lang == "py" then
    lang = "python"
  end

  local parts = {}

  table.insert(parts, string.format("@%s#%d-%d", file, item.line, item.end_line))
  table.insert(parts, "")

  if opts.include_code then
    table.insert(parts, "```" .. lang)
    table.insert(parts, item.code_chunk or "")
    table.insert(parts, "```")
    table.insert(parts, "")
  end

  table.insert(parts, item.comment or "")

  return table.concat(parts, "\n")
end

return M
