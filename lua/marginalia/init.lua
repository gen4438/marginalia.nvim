local M = {}
local store = require("marginalia.core.store")
local capture = require("marginalia.core.capture")
local display = require("marginalia.ui.display")

---Setup the plugin
---@param opts table|nil
function M.setup(opts)
  opts = opts or {}

  -- Initialize store
  store.setup(opts)

  -- Initialize capture
  capture.setup(opts)

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

  -- Manager
  vim.api.nvim_create_user_command("MarginaliaManager", function()
    require("marginalia.ui.display").open_manager()
  end, { desc = "Open annotation manager" })

  -- fzf-lua search
  vim.api.nvim_create_user_command("MarginaliaSearch", function()
    require("marginalia.integrations.fzf").pick()
  end, { desc = "Search annotations with fzf-lua" })

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

-- Public API
M.open_list = display.open_list
M.open_manager = display.open_manager
M.annotate = capture.process_selection
M.search = function()
  require("marginalia.integrations.fzf").pick()
end

return M
