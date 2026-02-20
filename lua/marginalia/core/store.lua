local M = {}
local project = require("marginalia.utils.project")
local Path = require("plenary.path")

-- State
local annotations = {}
local config = {}

---Initialize the store
---@param opts table|nil
function M.setup(opts)
  opts = opts or {}
  config.data_dir = opts.data_dir or (vim.fn.stdpath("data") .. "/marginalia")
  M._reset()

  -- Ensure data directory exists
  local p = Path:new(config.data_dir)
  if not p:exists() then
    p:mkdir({ parents = true })
  end

  -- Load existing annotations from disk
  M.load()
end

---Reset internal state (for testing)
function M._reset()
  annotations = {}
end

---Get the file path for current project storage
---@return table|nil Path object
function M.get_file_path()
  local root = project.root()
  if not root then
    return nil
  end

  -- Use sha256 of root path to generate unique filename
  local filename = vim.fn.sha256(root) .. ".json"
  return Path:new(config.data_dir):joinpath(filename)
end

---Add an annotation
---@param params table {file=string, line=number, end_line=number, comment=string, code_chunk=string}
function M.add(params)
  if not params.id then
    -- Generate simple unique ID
    params.id = string.format("%d-%d", os.time(), math.random(10000))
  end
  table.insert(annotations, params)
end

---Remove an annotation by ID
---@param id string
---@return boolean success
function M.remove(id)
  for i, item in ipairs(annotations) do
    if item.id == id then
      table.remove(annotations, i)
      return true
    end
  end
  return false
end

---Get all annotations for current project
---@return table[] list of annotations
function M.list()
  return annotations
end

---Get a single annotation by ID
---@param id string
---@return table|nil
function M.get(id)
  for _, item in ipairs(annotations) do
    if item.id == id then
      return item
    end
  end
  return nil
end

---Sort annotations using Neovim's built-in :sort command
---@param sort_args string|nil Arguments to pass to :sort (e.g. "n", "! n", "")
---  "!" prefix is treated as :sort! (reverse), remaining flags are appended.
function M.sort(sort_args)
  if #annotations <= 1 then
    return
  end

  sort_args = sort_args or ""

  -- Generate sort keys: "@file#line_range\tindex"
  -- Line numbers are zero-padded so lexicographic sort gives correct numeric order
  local keys = {}
  for i, item in ipairs(annotations) do
    local start_line = tonumber(item.line) or 0
    local end_line = tonumber(item.end_line) or start_line
    local line_range
    if end_line > start_line then
      line_range = string.format("%010d-%010d", start_line, end_line)
    else
      line_range = string.format("%010d", start_line)
    end
    table.insert(keys, string.format("@%s#%s\t%d", item.file or "", line_range, i))
  end

  -- Use a temp buffer with :sort command
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, keys)

  -- Build :sort command: "!" must be directly attached (":sort!" not ":sort !")
  local bang = ""
  local flags = sort_args
  if flags:match("^!") then
    bang = "!"
    flags = flags:sub(2):match("^%s*(.*)$") or ""
  end
  local sort_cmd = "sort" .. bang
  if flags ~= "" then
    sort_cmd = sort_cmd .. " " .. flags
  end

  vim.api.nvim_buf_call(buf, function()
    vim.cmd(sort_cmd)
  end)

  local sorted_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.api.nvim_buf_delete(buf, { force = true })

  -- Extract indices and reorder annotations
  local new_annotations = {}
  for _, line in ipairs(sorted_lines) do
    local idx = tonumber(line:match("\t(%d+)$"))
    if idx and annotations[idx] then
      table.insert(new_annotations, annotations[idx])
    end
  end
  annotations = new_annotations
end

---Reorder and filter annotations by ordered list of IDs
---Annotations not in ordered_ids are removed.
---@param ordered_ids string[]
function M.reorder(ordered_ids)
  local id_map = {}
  for _, item in ipairs(annotations) do
    id_map[item.id] = item
  end

  local new_annotations = {}
  for _, id in ipairs(ordered_ids) do
    if id_map[id] then
      table.insert(new_annotations, id_map[id])
    end
  end

  annotations = new_annotations
end

---Save annotations to disk
function M.save()
  local path = M.get_file_path()
  if not path then
    return
  end

  -- Serialize to JSON
  local encoded = vim.fn.json_encode(annotations)
  path:write(encoded, "w")
end

---Load annotations from disk
function M.load()
  M._reset()
  local path = M.get_file_path()
  if not path or not path:exists() then
    return
  end

  local content = path:read()
  if content and content ~= "" then
    local ok, decoded = pcall(vim.fn.json_decode, content)
    if ok and type(decoded) == "table" then
      annotations = decoded
    end
  end
end

return M
