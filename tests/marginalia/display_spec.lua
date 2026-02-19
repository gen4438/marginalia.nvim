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

  it("renders multi-line annotation blocks with code and comment", function()
    local store_list_stub = stub(store, "list")
    store_list_stub.returns({
      {
        id = "ann-1",
        file = "lua/test.lua",
        line = 7,
        end_line = 12,
        code_chunk = "local x = 1",
        comment = "first line\nsecond line",
      },
    })
    stub(store, "reorder")
    stub(store, "save")

    local ok = pcall(display.open_manager)
    assert.is_true(ok)

    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    assert.is_true(manager_buf > 0)

    local lines = vim.api.nvim_buf_get_lines(manager_buf, 0, -1, false)
    -- Line 1: header, Line 2: separator
    -- Line 3: @lua/test.lua#7-12
    assert.are.same("@lua/test.lua#7-12", lines[3])
    -- Line 4: code fence open
    assert.are.same("```lua", lines[4])
    -- Line 5: code content
    assert.are.same("local x = 1", lines[5])
    -- Line 6: code fence close
    assert.are.same("```", lines[6])
    -- Line 7: first comment line
    assert.are.same("first line", lines[7])
    -- Line 8: second comment line
    assert.are.same("second line", lines[8])

    vim.api.nvim_buf_delete(manager_buf, { force = true })
    store.list:revert()
    store.reorder:revert()
    store.save:revert()
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
    stub(store, "reorder")
    stub(store, "save")

    local ok = pcall(display.open_manager)
    assert.is_true(ok)

    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    assert.is_true(manager_buf > 0)

    local lines = vim.api.nvim_buf_get_lines(manager_buf, 0, -1, false)
    -- No code block since code_chunk is nil
    assert.are.same("@lua/test.lua#5", lines[3])
    assert.are.same("single line", lines[4])

    vim.api.nvim_buf_delete(manager_buf, { force = true })
    store.list:revert()
    store.reorder:revert()
    store.save:revert()
  end)

  it("renders annotation without code_chunk (no code fence)", function()
    local store_list_stub = stub(store, "list")
    store_list_stub.returns({
      {
        id = "ann-3",
        file = "lua/test.lua",
        line = 1,
        end_line = 3,
        comment = "just a comment",
      },
    })
    stub(store, "reorder")
    stub(store, "save")

    local ok = pcall(display.open_manager)
    assert.is_true(ok)

    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    assert.is_true(manager_buf > 0)

    local lines = vim.api.nvim_buf_get_lines(manager_buf, 0, -1, false)
    assert.are.same("@lua/test.lua#1-3", lines[3])
    -- No code fence lines, directly the comment
    assert.are.same("just a comment", lines[4])
    -- Should be only 4 lines total (header, separator, @header, comment)
    assert.are.same(4, #lines)

    vim.api.nvim_buf_delete(manager_buf, { force = true })
    store.list:revert()
    store.reorder:revert()
    store.save:revert()
  end)

  it("separates multiple annotation blocks with blank lines", function()
    local store_list_stub = stub(store, "list")
    store_list_stub.returns({
      {
        id = "ann-a",
        file = "a.lua",
        line = 1,
        end_line = 1,
        comment = "first",
      },
      {
        id = "ann-b",
        file = "b.lua",
        line = 2,
        end_line = 2,
        comment = "second",
      },
    })
    stub(store, "reorder")
    stub(store, "save")

    local ok = pcall(display.open_manager)
    assert.is_true(ok)

    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    assert.is_true(manager_buf > 0)

    local lines = vim.api.nvim_buf_get_lines(manager_buf, 0, -1, false)
    -- header, separator, @a.lua#1, first, (blank), @b.lua#2, second
    assert.are.same("@a.lua#1", lines[3])
    assert.are.same("first", lines[4])
    assert.are.same("", lines[5])
    assert.are.same("@b.lua#2", lines[6])
    assert.are.same("second", lines[7])

    vim.api.nvim_buf_delete(manager_buf, { force = true })
    store.list:revert()
    store.reorder:revert()
    store.save:revert()
  end)
end)
