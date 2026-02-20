local input = require("marginalia.ui.input")

describe("ui.input", function()
  it("opens a floating window and captures input", function()
    local result = nil
    local ctx = input.open(function(lines)
      result = lines
    end)

    assert.truthy(ctx.win_id)
    assert.truthy(ctx.buf_id)
    assert.is_true(vim.api.nvim_win_is_valid(ctx.win_id))

    -- Set content
    vim.api.nvim_buf_set_lines(ctx.buf_id, 0, -1, false, { "Test Line 1", "Test Line 2" })

    -- Verify window is float
    local config = vim.api.nvim_win_get_config(ctx.win_id)
    assert.truthy(config.relative ~= "")

    -- Trigger submit mechanism
    -- We assume the context returned allows programmatic submission for testing
    if ctx.submit then
      ctx.submit()
    else
      -- Fallback: try to execute the mapping if we knew it
      -- Or fail if not implemented
      vim.cmd("stopinsert")
      -- but validation depends on this.
    end

    assert.are.same({ "Test Line 1", "Test Line 2" }, result)

    -- Window should be closed
    -- Note: nvim_win_is_valid might still return true immediately if close is deferred?
    -- Usually nvim_win_close is synchronous.
    assert.is_false(vim.api.nvim_win_is_valid(ctx.win_id))
  end)
end)
