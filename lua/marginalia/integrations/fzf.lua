local M = {}
local store = require("marginalia.core.store")
local project = require("marginalia.utils.project")

---Open fzf-lua picker for annotations
function M.pick()
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua is not installed.", vim.log.levels.WARN)
    return
  end

  local items = store.list() or {}
  if #items == 0 then
    vim.notify("No annotations found.", vim.log.levels.INFO)
    return
  end

  local entries = {}
  local entry_map = {}

  for _, item in ipairs(items) do
    local start_line = tonumber(item.line) or 0
    local end_line = tonumber(item.end_line) or start_line
    local line_range
    if end_line > start_line then
      line_range = string.format("%d-%d", start_line, end_line)
    else
      line_range = tostring(start_line)
    end

    -- Normalize comment for single-line display
    local comment = (item.comment or ""):gsub("[\r\n]+", " ")
    local entry = string.format("%s:%s | %s", item.file or "", line_range, comment)
    table.insert(entries, entry)
    entry_map[entry] = item
  end

  fzf_lua.fzf_exec(entries, {
    prompt = "Marginalia> ",
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then
          return
        end
        local item = entry_map[selected[1]]
        if not item then
          return
        end

        local file = item.file
        local root = project.root()
        if root then
          file = root .. "/" .. file
        end

        vim.cmd("edit " .. vim.fn.fnameescape(file))
        pcall(vim.api.nvim_win_set_cursor, 0, { tonumber(item.line) or 1, 0 })
      end,
    },
  })
end

return M
