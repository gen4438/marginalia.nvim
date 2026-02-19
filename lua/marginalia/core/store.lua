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
