local M = {}

---Find project root
---@param start_path string|nil path to start searching from, defaults to cwd
---@return string|nil absolute path to project root
function M.root(start_path)
  start_path = start_path or vim.loop.cwd()
  local markers = { ".git", ".hg", "Makefile", "package.json", "setup.py", "Cargo.toml", "pyproject.toml" }

  -- First try finding as file
  local results = vim.fs.find(markers, {
    path = start_path,
    upward = true,
    limit = 1,
    type = "file",
  })

  if #results > 0 then
    return vim.fs.dirname(results[1])
  end

  -- Then try finding as directory (e.g. .git, .hg)
  results = vim.fs.find(markers, {
    path = start_path,
    upward = true,
    limit = 1,
    type = "directory",
  })

  if #results > 0 then
    return vim.fs.dirname(results[1])
  end

  return start_path
end

return M
