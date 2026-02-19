local M = {}
local store = require("marginalia.core.store")
local capture = require("marginalia.core.capture")

---Setup the plugin
---@param opts table|nil
function M.setup(opts)
  opts = opts or {}

  -- Initialize store
  store.setup(opts)

  -- Create user command
  -- Use range=true so that '<,'> marks are set correctly when invoked visually
  vim.api.nvim_create_user_command("MarginaliaAnnotate", function()
    capture.process_selection()
  end, {
    range = true,
    desc = "Annotate selected code block",
  })

  -- List annotations
  vim.api.nvim_create_user_command("MarginaliaList", function()
    require("marginalia.ui.display").open_list()
  end, { desc = "List all annotations" })

  -- Optional: Default keymappings
  if opts.default_mappings then
    vim.keymap.set(
      "v",
      "<leader>ma",
      ":MarginaliaAnnotate<CR>",
      { noremap = true, silent = true, desc = "Marginalia Annotate" }
    )
  end
end

return M
