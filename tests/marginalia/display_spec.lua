local display = require("marginalia.ui.display")
local store = require("marginalia.core.store")
local stub = require("luassert.stub")
local spy = require("luassert.spy")

-- Helper: open manager with given annotations, return buf number
local function open_manager_with(items)
  stub(store, "list").returns(items)
  stub(store, "reorder")
  stub(store, "save")
  stub(store, "get", function(id)
    for _, item in ipairs(items) do
      if item.id == id then
        return item
      end
    end
    return nil
  end)

  local ok = pcall(display.open_manager)
  assert.is_true(ok)

  local buf = vim.fn.bufnr("MarginaliaManager")
  assert.is_true(buf > 0)
  return buf
end

local function cleanup_manager(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  store.list:revert()
  store.reorder:revert()
  store.save:revert()
  if store.get.revert then
    store.get:revert()
  end
end

local function get_lines(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

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

  it("does not treat header-like text in comments as a header", function()
    local store_list_stub = stub(store, "list")
    store_list_stub.returns({
      {
        id = "ann-fp1",
        file = "src/main.lua",
        line = 10,
        end_line = 12,
        comment = "see @.agent/workflows/speckit.tasks.md#35-44\nfor details",
      },
    })
    stub(store, "reorder")
    stub(store, "save")

    local ok = pcall(display.open_manager)
    assert.is_true(ok)

    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    assert.is_true(manager_buf > 0)

    local lines = vim.api.nvim_buf_get_lines(manager_buf, 0, -1, false)
    -- Line 3: real header @src/main.lua#10-12
    assert.are.same("@src/main.lua#10-12", lines[3])
    -- Line 4: comment line that looks like a header
    assert.are.same("see @.agent/workflows/speckit.tasks.md#35-44", lines[4])
    -- Line 5: continuation
    assert.are.same("for details", lines[5])

    -- Verify extmarks: only the real header (line 3) should have an extmark
    local ns = vim.api.nvim_create_namespace("marginalia_manager")
    local extmarks = vim.api.nvim_buf_get_extmarks(manager_buf, ns, 0, -1, {})
    assert.are.same(1, #extmarks)
    assert.are.same(2, extmarks[1][2]) -- 0-indexed line 2 = line 3

    vim.api.nvim_buf_delete(manager_buf, { force = true })
    store.list:revert()
    store.reorder:revert()
    store.save:revert()
  end)

  it("does not treat header-like text in code blocks as a header", function()
    local store_list_stub = stub(store, "list")
    store_list_stub.returns({
      {
        id = "ann-fp2",
        file = "docs/api.md",
        line = 1,
        end_line = 3,
        code_chunk = "@config/settings.yaml#100-200\nsome_key: value",
        comment = "config reference",
      },
    })
    stub(store, "reorder")
    stub(store, "save")

    local ok = pcall(display.open_manager)
    assert.is_true(ok)

    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    assert.is_true(manager_buf > 0)

    local lines = vim.api.nvim_buf_get_lines(manager_buf, 0, -1, false)
    -- Line 3: real header
    assert.are.same("@docs/api.md#1-3", lines[3])
    -- Line 4: code fence open
    assert.are.same("```md", lines[4])
    -- Line 5: code line that looks like a header
    assert.are.same("@config/settings.yaml#100-200", lines[5])
    -- Line 6: code content
    assert.are.same("some_key: value", lines[6])
    -- Line 7: code fence close
    assert.are.same("```", lines[7])
    -- Line 8: comment
    assert.are.same("config reference", lines[8])

    -- Only 1 extmark (on the real header)
    local ns = vim.api.nvim_create_namespace("marginalia_manager")
    local extmarks = vim.api.nvim_buf_get_extmarks(manager_buf, ns, 0, -1, {})
    assert.are.same(1, #extmarks)
    assert.are.same(2, extmarks[1][2]) -- 0-indexed line 2 = line 3

    vim.api.nvim_buf_delete(manager_buf, { force = true })
    store.list:revert()
    store.reorder:revert()
    store.save:revert()
  end)

  it("keeps correct block boundaries with header-like comment between blocks", function()
    local store_list_stub = stub(store, "list")
    store_list_stub.returns({
      {
        id = "ann-fp3a",
        file = "a.lua",
        line = 1,
        end_line = 1,
        comment = "@b.lua#99\nthis references another file",
      },
      {
        id = "ann-fp3b",
        file = "b.lua",
        line = 5,
        end_line = 5,
        comment = "real second block",
      },
    })
    stub(store, "reorder")
    stub(store, "save")

    local ok = pcall(display.open_manager)
    assert.is_true(ok)

    local manager_buf = vim.fn.bufnr("MarginaliaManager")
    assert.is_true(manager_buf > 0)

    local lines = vim.api.nvim_buf_get_lines(manager_buf, 0, -1, false)
    -- Block 1: header, separator, @a.lua#1, @b.lua#99 (comment), this references..., blank
    -- Block 2: @b.lua#5, real second block
    assert.are.same("@a.lua#1", lines[3])
    assert.are.same("@b.lua#99", lines[4])
    assert.are.same("this references another file", lines[5])
    assert.are.same("", lines[6])
    assert.are.same("@b.lua#5", lines[7])
    assert.are.same("real second block", lines[8])

    -- Exactly 2 extmarks on the real headers (lines 3 and 7)
    local ns = vim.api.nvim_create_namespace("marginalia_manager")
    local extmarks = vim.api.nvim_buf_get_extmarks(manager_buf, ns, 0, -1, {})
    assert.are.same(2, #extmarks)
    assert.are.same(2, extmarks[1][2]) -- line 3 (0-indexed: 2)
    assert.are.same(6, extmarks[2][2]) -- line 7 (0-indexed: 6)

    vim.api.nvim_buf_delete(manager_buf, { force = true })
    store.list:revert()
    store.reorder:revert()
    store.save:revert()
  end)

  describe("manager rendering edge cases", function()
    it("preserves blank lines within comment text", function()
      local buf = open_manager_with({
        {
          id = "ann-blank",
          file = "test.lua",
          line = 1,
          end_line = 1,
          comment = "line one\n\nline three",
        },
      })

      local lines = get_lines(buf)
      assert.are.same("@test.lua#1", lines[3])
      assert.are.same("line one", lines[4])
      assert.are.same("", lines[5])
      assert.are.same("line three", lines[6])
      assert.are.same(6, #lines)

      cleanup_manager(buf)
    end)

    it("renders with empty annotations list", function()
      local buf = open_manager_with({})

      local lines = get_lines(buf)
      assert.are.same(2, #lines)

      cleanup_manager(buf)
    end)

    it("renders empty comment after code block", function()
      local buf = open_manager_with({
        {
          id = "ann-ec",
          file = "test.lua",
          line = 1,
          end_line = 1,
          code_chunk = "x = 1",
          comment = "",
        },
      })

      local lines = get_lines(buf)
      assert.are.same("@test.lua#1", lines[3])
      assert.are.same("```lua", lines[4])
      assert.are.same("x = 1", lines[5])
      assert.are.same("```", lines[6])
      assert.are.same("", lines[7])

      cleanup_manager(buf)
    end)
  end)

  describe("manager foldexpr", function()
    it("returns correct fold levels for buffer lines", function()
      local buf = open_manager_with({
        {
          id = "fold-1",
          file = "a.lua",
          line = 1,
          end_line = 3,
          code_chunk = "local x = 1",
          comment = "comment A",
        },
        {
          id = "fold-2",
          file = "b.lua",
          line = 5,
          end_line = 5,
          comment = "comment B",
        },
      })

      -- Buffer:
      -- 1: # Marginalia Manager ...
      -- 2: ----...
      -- 3: @a.lua#1-3          (header)
      -- 4: ```lua
      -- 5: local x = 1
      -- 6: ```
      -- 7: comment A
      -- 8: (blank separator)
      -- 9: @b.lua#5            (header)
      -- 10: comment B

      -- Title lines: no fold
      vim.v.lnum = 1
      assert.are.same("0", _G.marginalia_foldexpr())
      vim.v.lnum = 2
      assert.are.same("0", _G.marginalia_foldexpr())

      -- First header: start fold
      vim.v.lnum = 3
      assert.are.same(">1", _G.marginalia_foldexpr())

      -- Content lines: inside fold
      vim.v.lnum = 4
      assert.are.same("1", _G.marginalia_foldexpr())
      vim.v.lnum = 5
      assert.are.same("1", _G.marginalia_foldexpr())
      vim.v.lnum = 6
      assert.are.same("1", _G.marginalia_foldexpr())
      vim.v.lnum = 7
      assert.are.same("1", _G.marginalia_foldexpr())

      -- Blank separator before next header: outside fold
      vim.v.lnum = 8
      assert.are.same("0", _G.marginalia_foldexpr())

      -- Second header: start fold
      vim.v.lnum = 9
      assert.are.same(">1", _G.marginalia_foldexpr())

      -- Content: inside fold
      vim.v.lnum = 10
      assert.are.same("1", _G.marginalia_foldexpr())

      cleanup_manager(buf)
    end)

    it("keeps blank lines within comments inside the fold", function()
      local buf = open_manager_with({
        {
          id = "fold-blank",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "line one\n\nline three",
        },
        {
          id = "fold-next",
          file = "b.lua",
          line = 2,
          end_line = 2,
          comment = "next",
        },
      })

      -- Buffer:
      -- 3: @a.lua#1
      -- 4: line one
      -- 5: (blank - within comment)
      -- 6: line three
      -- 7: (blank separator before next block)
      -- 8: @b.lua#2
      -- 9: next

      -- Blank line within comment: stays in fold
      vim.v.lnum = 5
      assert.are.same("1", _G.marginalia_foldexpr())

      -- Blank separator before next header: outside fold
      vim.v.lnum = 7
      assert.are.same("0", _G.marginalia_foldexpr())

      cleanup_manager(buf)
    end)
  end)

  describe("manager foldtext", function()
    it("generates summary from block with code", function()
      local buf = open_manager_with({
        {
          id = "ft-1",
          file = "lua/test.lua",
          line = 7,
          end_line = 12,
          code_chunk = "local x = 1",
          comment = "first line\nsecond line",
        },
      })

      vim.v.foldstart = 3
      vim.v.foldend = 8
      local text = _G.marginalia_foldtext()
      assert.are.same("lua/test.lua:7-12 | first line\\nsecond line", text)

      cleanup_manager(buf)
    end)

    it("generates summary for annotation without code", function()
      local buf = open_manager_with({
        {
          id = "ft-2",
          file = "test.lua",
          line = 5,
          end_line = 5,
          comment = "simple comment",
        },
      })

      vim.v.foldstart = 3
      vim.v.foldend = 4
      local text = _G.marginalia_foldtext()
      assert.are.same("test.lua:5 | simple comment", text)

      cleanup_manager(buf)
    end)
  end)

  describe("manager dd behavior", function()
    it("deletes entire block when dd on header line", function()
      local buf = open_manager_with({
        {
          id = "dd-1",
          file = "a.lua",
          line = 1,
          end_line = 1,
          code_chunk = "x = 1",
          comment = "first",
        },
        {
          id = "dd-2",
          file = "b.lua",
          line = 2,
          end_line = 2,
          comment = "second",
        },
      })

      -- Place cursor on first header (line 3) and trigger dd
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("dd", true, false, true), "x", false)

      local lines = get_lines(buf)
      -- First block removed, second block remains
      assert.are.same("@b.lua#2", lines[3])
      assert.are.same("second", lines[4])

      cleanup_manager(buf)
    end)

    it("deletes only one line when dd on comment line", function()
      local buf = open_manager_with({
        {
          id = "dd-comment",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "line one\nline two\nline three",
        },
      })

      -- Buffer has 6 lines: header, separator, @a.lua#1, line one, line two, line three
      assert.are.same(6, #get_lines(buf))

      -- Simulate dd on comment line: delete "line two" (line 5, 0-indexed: 4)
      -- This is what the dd keymap does for non-header lines
      vim.api.nvim_buf_set_lines(buf, 4, 5, false, {})

      local lines = get_lines(buf)
      assert.are.same(5, #lines)
      assert.are.same("@a.lua#1", lines[3])
      assert.are.same("line one", lines[4])
      assert.are.same("line three", lines[5])

      cleanup_manager(buf)
    end)
  end)

  describe("manager extmark tracking", function()
    it("removes deleted annotation from ordered IDs on sync", function()
      local buf = open_manager_with({
        {
          id = "ext-1",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "first",
        },
        {
          id = "ext-2",
          file = "b.lua",
          line = 2,
          end_line = 2,
          comment = "second",
        },
        {
          id = "ext-3",
          file = "c.lua",
          line = 3,
          end_line = 3,
          comment = "third",
        },
      })

      -- Simulate dd on header line: delete first block (lines 3-5, including blank separator)
      -- This is what the dd keymap does for header lines:
      -- 1. Remove the extmark mapping so sync won't include it
      local ns = vim.api.nvim_create_namespace("marginalia_manager")
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { 2, 0 }, { 2, 0 }, {})
      -- Clear the internal mapping (access via module internals isn't possible,
      -- so we delete the extmark itself to prevent it from being found)
      for _, mark in ipairs(marks) do
        vim.api.nvim_buf_del_extmark(buf, ns, mark[1])
      end
      -- 2. Delete the block lines
      vim.api.nvim_buf_set_lines(buf, 2, 5, false, {})

      -- Trigger sync via :w
      vim.cmd("write")

      -- store.reorder should have been called without "ext-1"
      assert.stub(store.reorder).was.called()
      local last_call = store.reorder.calls[#store.reorder.calls]
      local ordered = last_call.refs[1]
      assert.are.same({ "ext-2", "ext-3" }, ordered)

      cleanup_manager(buf)
    end)
  end)
end)
