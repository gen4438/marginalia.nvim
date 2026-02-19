local M = {}

local ext_lang_map = { rs = "rust", ts = "typescript", js = "javascript", py = "python" }

---Map file extension to language name for code fences
---@param ext string
---@return string
function M.ext_to_lang(ext)
  return ext_lang_map[ext] or ext
end

---Generate markdown for an annotation item
---@param item table {file, line, end_line, code_chunk, comment, ...}
---@param opts table|nil {include_code=boolean}
---@return string markdown content
function M.markdown(item, opts)
  opts = opts or {}
  local file = item.file or "unknown"
  local ext = file:match("%.([%w_]+)$") or ""
  local lang = M.ext_to_lang(ext)

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
