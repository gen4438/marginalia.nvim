local display = require("marginalia.ui.display")
local store = require("marginalia.core.store")
local stub = require("luassert.stub")
local spy = require("luassert.spy")

describe("display", function()
  it("populates and opens quickfix list", function()
    -- Stub store
    local store_list_stub = stub(store, "list")
    store_list_stub.returns({
      {
        file = "test.lua",
        line = 10,
        end_line = 12,
        comment = "Test Comment",
        code_chunk = "local x = 1",
      },
    })

    -- Spy on setqflist
    local setqflist_spy = spy.on(vim.fn, "setqflist")

    -- Spy on command execution (copen)
    -- Since spy on vim.cmd is unreliable across versions/implementations,
    -- we check effect or stub if display uses a helper.
    -- Assuming display calls `vim.cmd("copen")`.
    local cmd_stub = stub(vim, "cmd")

    display.open_list()

    -- Verify store usage
    assert.stub(store_list_stub).was.called()

    -- Verify setqflist called with correct data
    assert.spy(setqflist_spy).was.called()
    local qf_list = setqflist_spy.calls[1].refs[1]

    assert.are.same(1, #qf_list)
    assert.are.same("test.lua", qf_list[1].filename)
    assert.are.same(10, qf_list[1].lnum)
    assert.are.same("Test Comment", qf_list[1].text)

    -- Verify copen
    assert.stub(cmd_stub).was.called_with("copen")

    -- Cleanup
    store.list:revert()
    vim.fn.setqflist:revert()
    vim.cmd:revert()
  end)

  it("renders manager lines safely when comments contain newlines", function()
    local store_list_stub = stub(store, "list")
    store_list_stub.returns({
      {
        id = "ann-1",
        file = "lua/test.lua",
        line = 7,
        end_line = 12,
        comment = "first line\nsecond line",
      },
    })

    local ok = pcall(display.open_manager)
    assert.is_true(ok)

    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    assert.is_true(manager_buf > 0)

    local lines = vim.api.nvim_buf_get_lines(manager_buf, 0, -1, false)
    assert.are.same("lua/test.lua:7-12 | first line\\nsecond line", lines[3])

    vim.api.nvim_buf_delete(manager_buf, { force = true })
    store.list:revert()
  end)

  it("renders single line number when line == end_line", function()
    local store_list_stub = stub(store, "list")
    store_list_stub.returns({
      {
        id = "ann-2",
        file = "lua/test.lua",
        line = 5,
        end_line = 5,
        comment = "single line",
      },
    })

    local ok = pcall(display.open_manager)
    assert.is_true(ok)

    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    assert.is_true(manager_buf > 0)

    local lines = vim.api.nvim_buf_get_lines(manager_buf, 0, -1, false)
    assert.are.same("lua/test.lua:5 | single line", lines[3])

    vim.api.nvim_buf_delete(manager_buf, { force = true })
    store.list:revert()
  end)
end)
