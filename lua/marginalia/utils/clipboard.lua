local M = {}

---Copy text to system clipboard and unnamed register
---@param text string
function M.copy(text)
  -- Copy to system clipboard (+)
  -- Note: requires clipboard tool (xclip, wl-copy, pbcopy) or Neovim with clipboard support
  vim.fn.setreg("+", text)

  -- Copy to primary selection (*) if available?
  -- Usually + is enough for system.

  -- Copy to unnamed register (for p)
  vim.fn.setreg('"', text)

  print("Copied to clipboard.")
end

return M
