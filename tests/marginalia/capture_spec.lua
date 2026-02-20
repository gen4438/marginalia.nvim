local capture = require("marginalia.core.capture")
local store = require("marginalia.core.store")
local ui = require("marginalia.ui.input")
local stub = require("luassert.stub")

local clipboard = require("marginalia.utils.clipboard")

describe("capture", function()
  it("captures selection and saves into store", function()
    -- Creating spies
    local ui_open_stub = stub(ui, "open")
    local store_add_stub = stub(store, "add")
    stub(store, "save")
    local clipboard_copy_stub = stub(clipboard, "copy")

    -- Setup text buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local x = 1", "local y = 2", "print(x)" })
    vim.api.nvim_set_current_buf(buf)

    -- Set visual marks manually to simulate selection
    -- '< is start, '> is end. (1-based line, 0-based col)
    vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
    vim.api.nvim_buf_set_mark(buf, ">", 2, 0, {})

    -- Run capture
    capture.process_selection()

    -- Expect UI to open
    assert.stub(ui_open_stub).was.called()

    -- Verify code chunk extraction
    -- Simulate user inputting "My Comment" and submitting
    local callback = ui_open_stub.calls[1].refs[1]
    callback({ "My Comment" })

    -- Expect store.add to be called with correct data
    assert.stub(store_add_stub).was.called()
    local arg = store_add_stub.calls[1].refs[1]

    assert.are.same("My Comment", arg.comment)

    -- Check captured code
    -- We selected lines 1 and 2: "local x = 1\nlocal y = 2"
    assert.is_true(arg.code_chunk:find("local x = 1") ~= nil)
    assert.is_true(arg.code_chunk:find("local y = 2") ~= nil)

    -- Verify file path
    assert.truthy(arg.file)

    -- Verify clipboard copy
    assert.stub(clipboard_copy_stub).was.called()

    -- Cleanup
    ui.open:revert()
    store.add:revert()
    store.save:revert()
    clipboard.copy:revert()
  end)
end)
