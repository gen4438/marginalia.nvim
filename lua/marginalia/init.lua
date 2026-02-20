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

  -- Initialize display
  display.setup(opts)

  -- Create user commands for annotation
  -- Use range=true so that '<,'> marks are set correctly when invoked visually
  vim.api.nvim_create_user_command("MarginaliaAnnotate", function()
    capture.process_selection()
  end, {
    range = true,
    desc = "Annotate selected code block (default)",
  })

  vim.api.nvim_create_user_command("MarginaliaAnnotateCode", function()
    capture.process_selection({ include_code = true })
  end, {
    range = true,
    desc = "Annotate selected code block (include code)",
  })

  vim.api.nvim_create_user_command("MarginaliaAnnotateNoCode", function()
    capture.process_selection({ include_code = false })
  end, {
    range = true,
    desc = "Annotate selected code block (exclude code)",
  })

  vim.api.nvim_create_user_command("MarginaliaAnnotateLine", function()
    capture.process_line()
  end, {
    desc = "Annotate current line (default)",
  })

  vim.api.nvim_create_user_command("MarginaliaAnnotateLineCode", function()
    capture.process_line({ include_code = true })
  end, {
    desc = "Annotate current line (include code)",
  })

  vim.api.nvim_create_user_command("MarginaliaAnnotateLineNoCode", function()
    capture.process_line({ include_code = false })
  end, {
    desc = "Annotate current line (exclude code)",
  })

  -- List annotations
  vim.api.nvim_create_user_command("MarginaliaList", function()
    require("marginalia.ui.display").open_list()
  end, { desc = "List all annotations" })

  -- Manager
  vim.api.nvim_create_user_command("MarginaliaManager", function()
    require("marginalia.ui.display").open_manager()
  end, { desc = "Open annotation manager" })

  -- Sort annotations
  vim.api.nvim_create_user_command("MarginaliaSort", function(cmd_opts)
    local sort_args = ""
    if cmd_opts.bang then
      sort_args = "! "
    end
    sort_args = sort_args .. (cmd_opts.args or "")
    store.sort(sort_args)
    store.save()
    -- Re-render manager if it's open
    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    if manager_buf > 0 and vim.api.nvim_buf_is_valid(manager_buf) then
      display.render_manager()
      vim.api.nvim_buf_set_option(manager_buf, "modified", false)
    end
  end, { bang = true, nargs = "?", desc = "Sort annotations (passes flags to :sort)" })

  -- fzf-lua search
  vim.api.nvim_create_user_command("MarginaliaSearch", function()
    require("marginalia.integrations.fzf").pick()
  end, { desc = "Search annotations with fzf-lua" })

  -- Keymappings
  if opts.keymaps then
    local keymaps = opts.keymaps
    local map = function(name, mode, default_lhs, rhs, desc)
      local lhs = keymaps[name]
      if lhs == nil then
        lhs = default_lhs
      end
      if lhs then
        vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, desc = "Marginalia " .. desc })
      end
    end

    map("annotate", "v", "<leader>ma", ":MarginaliaAnnotate<CR>", "Annotate")
    map("annotate", "n", "<leader>ma", ":MarginaliaAnnotateLine<CR>", "Annotate line")
    map("list", "n", "<leader>ml", ":MarginaliaList<CR>", "List")
    map("manager", "n", "<leader>mm", ":MarginaliaManager<CR>", "Manager")
    map("search", "n", "<leader>ms", ":MarginaliaSearch<CR>", "Search")
  end
end

-- Public API
M.open_list = display.open_list
M.open_manager = display.open_manager
M.annotate = capture.process_selection
M.annotate_line = capture.process_line
M.search = function()
  require("marginalia.integrations.fzf").pick()
end

return M
