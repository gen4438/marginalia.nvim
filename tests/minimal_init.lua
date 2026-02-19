-- tests/minimal_init.lua
local M = {}

function M.root(root)
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
end

function M.load(plugin)
  local name = plugin:match(".*/(.*)")
  local package_root = M.root(".tests/site/pack/deps/start/")
  if not vim.loop.fs_stat(package_root .. name) then
    print("Installing " .. plugin)
    vim.fn.mkdir(package_root, "p")
    vim.fn.system({
      "git",
      "clone",
      "--depth=1",
      "https://github.com/" .. plugin,
      package_root .. name,
    })
  end
end

M.load("nvim-lua/plenary.nvim")
vim.opt.rtp:prepend(".")
vim.opt.rtp:prepend(M.root(".tests/site/pack/deps/start/plenary.nvim"))
