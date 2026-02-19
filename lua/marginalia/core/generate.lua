local M = {}

---Generate markdown for an annotation item
---@param item table {file, line, end_line, code_chunk, comment, ...}
---@return string markdown content
function M.markdown(item)
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
  -- Format:
  -- ## [Comment]
  -- File: [path]:[lines]
  -- ```[lang]
  -- [code]
  -- ```

  table.insert(parts, "## " .. (item.comment or ""))
  table.insert(parts, string.format("File: `%s:%d-%d`", file, item.line, item.end_line))
  table.insert(parts, "")
  table.insert(parts, "```" .. lang)
  table.insert(parts, item.code_chunk or "")
  table.insert(parts, "```")

  return table.concat(parts, "\n")
end

return M
