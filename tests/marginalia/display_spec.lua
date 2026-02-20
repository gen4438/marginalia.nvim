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
    display.setup({ include_code = true })
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
    display.setup({ include_code = true })
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
      display.setup({ include_code = true })
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

    it("displays absolute file path inside cwd as relative path", function()
      local cwd = vim.fn.getcwd()
      local abs_file = cwd .. "/src/main.lua"
      local buf = open_manager_with({
        {
          id = "abs-in-cwd",
          file = abs_file,
          line = 10,
          end_line = 15,
          comment = "inside cwd",
        },
      })

      local lines = get_lines(buf)
      assert.are.same("@src/main.lua#10-15", lines[3])

      cleanup_manager(buf)
    end)

    it("displays absolute file path outside cwd as absolute path", function()
      local abs_file = "/tmp/external_project/file.lua"
      local buf = open_manager_with({
        {
          id = "abs-out-cwd",
          file = abs_file,
          line = 3,
          end_line = 3,
          comment = "outside cwd",
        },
      })

      local lines = get_lines(buf)
      assert.are.same("@/tmp/external_project/file.lua#3", lines[3])

      cleanup_manager(buf)
    end)
  end)

  describe("manager CR navigation", function()
    it("opens relative path by joining with project root", function()
      local buf = open_manager_with({
        {
          id = "nav-rel",
          file = "src/foo.lua",
          line = 1,
          end_line = 1,
          comment = "relative",
        },
      })

      local project = require("marginalia.utils.project")
      stub(project, "root").returns("/project/root")

      local cmd_stub = stub(vim, "cmd")

      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

      local edit_arg = nil
      for _, call in ipairs(cmd_stub.calls) do
        local arg = tostring(call.refs[1])
        if arg:match("^edit ") then
          edit_arg = arg
          break
        end
      end

      assert.is_not_nil(edit_arg)
      assert.truthy(edit_arg:find("/project/root/src/foo.lua", 1, true))

      project.root:revert()
      vim.cmd:revert()
      -- bwipeout! was stubbed so the buffer still exists; delete it manually
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      store.list:revert()
      store.reorder:revert()
      store.save:revert()
      if store.get.revert then
        store.get:revert()
      end
    end)

    it("opens absolute path without joining project root", function()
      local abs_file = "/tmp/external_project/bar.lua"
      local buf = open_manager_with({
        {
          id = "nav-abs",
          file = abs_file,
          line = 5,
          end_line = 5,
          comment = "external",
        },
      })

      local project = require("marginalia.utils.project")
      stub(project, "root").returns("/project/root")

      local cmd_stub = stub(vim, "cmd")

      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

      local edit_arg = nil
      for _, call in ipairs(cmd_stub.calls) do
        local arg = tostring(call.refs[1])
        if arg:match("^edit ") then
          edit_arg = arg
          break
        end
      end

      assert.is_not_nil(edit_arg)
      -- Must be the bare absolute path, not /project/root/tmp/...
      assert.truthy(edit_arg:find(vim.fn.fnameescape(abs_file), 1, true))
      assert.falsy(edit_arg:find("/project/root" .. abs_file, 1, true))

      project.root:revert()
      vim.cmd:revert()
      -- bwipeout! was stubbed so the buffer still exists; delete it manually
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      store.list:revert()
      store.reorder:revert()
      store.save:revert()
      if store.get.revert then
        store.get:revert()
      end
    end)
  end)

  describe("manager foldexpr", function()
    it("returns correct fold levels for buffer lines", function()
      display.setup({ include_code = true })
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
      display.setup({ include_code = true })
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
      display.setup({ include_code = true })
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
      display.setup({ include_code = true })
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

  describe("manager second open", function()
    it("creates fresh buffer after hidden buffer is reopened", function()
      local items = {
        {
          id = "reopen-1",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "first",
        },
        {
          id = "reopen-2",
          file = "b.lua",
          line = 2,
          end_line = 2,
          comment = "second",
        },
      }
      local buf1 = open_manager_with(items)

      -- Simulate closing the window (buffer becomes hidden, not wiped)
      -- The buffer has bufhidden=hide from nvim_create_buf(false, true)
      vim.cmd("enew") -- switch to a new buffer, hiding the manager

      -- Verify the old buffer is still valid (hidden)
      assert.is_true(vim.api.nvim_buf_is_valid(buf1))

      -- Revert stubs and re-stub for the second open
      store.list:revert()
      store.reorder:revert()
      store.save:revert()
      if store.get.revert then
        store.get:revert()
      end

      -- Open manager again (second time)
      local buf2 = open_manager_with(items)

      -- A fresh buffer should have been created (old one wiped)
      assert.is_not.equal(buf1, buf2)
      assert.is_false(vim.api.nvim_buf_is_valid(buf1))

      -- Verify content is correct
      local lines = get_lines(buf2)
      assert.are.same("@a.lua#1", lines[3])
      assert.are.same("first", lines[4])

      cleanup_manager(buf2)
    end)

    it("syncs deletion correctly after reopening manager", function()
      local items = {
        {
          id = "sync-1",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "first",
        },
        {
          id = "sync-2",
          file = "b.lua",
          line = 2,
          end_line = 2,
          comment = "second",
        },
      }
      local buf1 = open_manager_with(items)

      -- Close the manager window (buffer becomes hidden)
      vim.cmd("enew")
      assert.is_true(vim.api.nvim_buf_is_valid(buf1))

      -- Revert stubs and re-stub for second open
      store.list:revert()
      store.reorder:revert()
      store.save:revert()
      if store.get.revert then
        store.get:revert()
      end

      local buf2 = open_manager_with(items)

      -- Delete the first annotation header (line 3) via dd keymap
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("dd", true, false, true), "x", false)

      -- Save with :w
      vim.cmd("write")

      -- store.reorder should have been called without "sync-1"
      assert.stub(store.reorder).was.called()
      local last_call = store.reorder.calls[#store.reorder.calls]
      local ordered = last_call.refs[1]
      assert.are.same({ "sync-2" }, ordered)

      cleanup_manager(buf2)
    end)
  end)

  describe("manager include_code option", function()
    it("hides code blocks when include_code is false (default)", function()
      display.setup({ include_code = false })
      local buf = open_manager_with({
        {
          id = "ic-off",
          file = "lua/test.lua",
          line = 7,
          end_line = 12,
          code_chunk = "local x = 1",
          comment = "first line\nsecond line",
        },
      })

      local lines = get_lines(buf)
      -- Line 3: @lua/test.lua#7-12
      assert.are.same("@lua/test.lua#7-12", lines[3])
      -- No code fence — comment starts immediately
      assert.are.same("first line", lines[4])
      assert.are.same("second line", lines[5])
      assert.are.same(5, #lines)

      -- Verify no code fence anywhere
      for _, l in ipairs(lines) do
        assert.falsy(l:match("^```"), "unexpected code fence: " .. l)
      end

      cleanup_manager(buf)
    end)

    it("shows code blocks when include_code is true", function()
      display.setup({ include_code = true })
      local buf = open_manager_with({
        {
          id = "ic-on",
          file = "lua/test.lua",
          line = 7,
          end_line = 12,
          code_chunk = "local x = 1",
          comment = "first line\nsecond line",
        },
      })

      local lines = get_lines(buf)
      assert.are.same("@lua/test.lua#7-12", lines[3])
      assert.are.same("```lua", lines[4])
      assert.are.same("local x = 1", lines[5])
      assert.are.same("```", lines[6])
      assert.are.same("first line", lines[7])
      assert.are.same("second line", lines[8])

      cleanup_manager(buf)
    end)

    it("hides code blocks by default when setup is not called", function()
      -- Reset config by calling setup with empty opts
      display.setup({})
      local buf = open_manager_with({
        {
          id = "ic-default",
          file = "test.lua",
          line = 1,
          end_line = 1,
          code_chunk = "x = 1",
          comment = "a comment",
        },
      })

      local lines = get_lines(buf)
      assert.are.same("@test.lua#1", lines[3])
      assert.are.same("a comment", lines[4])
      assert.are.same(4, #lines)

      cleanup_manager(buf)
    end)
  end)

  describe("manager sync robustness", function()
    it("excludes orphaned extmarks when block lines are manually deleted", function()
      local items = {
        {
          id = "orphan-1",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "first",
        },
        {
          id = "orphan-2",
          file = "b.lua",
          line = 2,
          end_line = 2,
          comment = "second",
        },
      }
      local buf = open_manager_with(items)

      -- Buffer:
      -- 1: # Marginalia Manager...
      -- 2: ----...
      -- 3: @a.lua#1       [extmark -> orphan-1]
      -- 4: first
      -- 5: (blank)
      -- 6: @b.lua#2       [extmark -> orphan-2]
      -- 7: second

      -- Manually delete lines 3-5 (the first block) without removing extmarks.
      -- This simulates visual select + delete. The extmark for orphan-1
      -- will survive and move to the next remaining line (@b.lua#2).
      vim.api.nvim_buf_set_lines(buf, 2, 5, false, {})

      -- Buffer after deletion:
      -- 1: # Marginalia Manager...
      -- 2: ----...
      -- 3: @b.lua#2  (orphan-1 extmark collapsed here + orphan-2 extmark)
      -- 4: second

      -- Trigger sync via :w
      vim.cmd("write")

      -- store.reorder should have been called with only orphan-2,
      -- because orphan-1's extmark is on @b.lua#2 (not its original header)
      assert.stub(store.reorder).was.called()
      local last_call = store.reorder.calls[#store.reorder.calls]
      local ordered = last_call.refs[1]
      assert.are.same({ "orphan-2" }, ordered)

      cleanup_manager(buf)
    end)

    it("syncs edited comments back to store", function()
      local items = {
        {
          id = "cedit-1",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "original comment",
        },
      }
      local buf = open_manager_with(items)

      -- Buffer:
      -- 1: # Marginalia Manager...
      -- 2: ----...
      -- 3: @a.lua#1
      -- 4: original comment

      -- Edit the comment line
      vim.api.nvim_buf_set_lines(buf, 3, 4, false, { "edited comment" })

      -- Trigger sync via :w
      vim.cmd("write")

      -- The item's comment should have been updated
      assert.are.same("edited comment", items[1].comment)

      cleanup_manager(buf)
    end)

    it("syncs multiline comment edits back to store", function()
      local items = {
        {
          id = "cedit-ml",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "line one\nline two",
        },
      }
      local buf = open_manager_with(items)

      -- Replace "line two" with "modified line two" and add "line three"
      vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "modified line two", "line three" })

      vim.cmd("write")

      assert.are.same("line one\nmodified line two\nline three", items[1].comment)

      cleanup_manager(buf)
    end)

    it("syncs edited code chunk back to store", function()
      display.setup({ include_code = true })
      local items = {
        {
          id = "cedit-code",
          file = "a.lua",
          line = 1,
          end_line = 1,
          code_chunk = "old code",
          comment = "original comment",
        },
      }
      local buf = open_manager_with(items)

      -- buffer has header, ```lua, old code, ```, original comment
      -- Replace "old code" with "new code"
      vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "new code" })

      vim.cmd("write")

      assert.are.same("new code", items[1].code_chunk)
      assert.are.same("original comment", items[1].comment)

      cleanup_manager(buf)
    end)

    it("clears code chunk when code block deleted", function()
      display.setup({ include_code = true })
      local items = {
        {
          id = "cedit-clear-code",
          file = "a.lua",
          line = 1,
          end_line = 1,
          code_chunk = "old code",
          comment = "original comment",
        },
      }
      local buf = open_manager_with(items)

      -- Delete code block lines (```lua, old code, ```)
      vim.api.nvim_buf_set_lines(buf, 3, 6, false, {})

      vim.cmd("write")

      assert.is_nil(items[1].code_chunk)
      assert.are.same("original comment", items[1].comment)

      cleanup_manager(buf)
    end)

    it("syncs correctly after title line is deleted", function()
      local items = {
        {
          id = "title-del-1",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "first",
        },
        {
          id = "title-del-2",
          file = "b.lua",
          line = 2,
          end_line = 2,
          comment = "second",
        },
      }
      local buf = open_manager_with(items)

      -- Delete the title line (line 1) and separator (line 2)
      vim.api.nvim_buf_set_lines(buf, 0, 2, false, {})

      -- Buffer after deletion:
      -- 1: @a.lua#1
      -- 2: first
      -- 3: (blank)
      -- 4: @b.lua#2
      -- 5: second

      -- Now delete the first block using dd on header
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("dd", true, false, true), "x", false)

      -- Trigger sync via :w
      vim.cmd("write")

      -- Only title-del-2 should remain
      assert.stub(store.reorder).was.called()
      local last_call = store.reorder.calls[#store.reorder.calls]
      local ordered = last_call.refs[1]
      assert.are.same({ "title-del-2" }, ordered)

      cleanup_manager(buf)
    end)

    it("preserves comments in code-fence blocks during sync", function()
      display.setup({ include_code = true })
      local items = {
        {
          id = "cfence-1",
          file = "a.lua",
          line = 1,
          end_line = 1,
          code_chunk = "x = 1",
          comment = "original",
        },
      }
      local buf = open_manager_with(items)

      -- Buffer:
      -- 1: # Marginalia Manager...
      -- 2: ----...
      -- 3: @a.lua#1
      -- 4: ```lua
      -- 5: x = 1
      -- 6: ```
      -- 7: original

      -- Edit the comment (line 7)
      vim.api.nvim_buf_set_lines(buf, 6, 7, false, { "updated" })

      vim.cmd("write")

      -- Comment should be updated, code fence content should not leak into comment
      assert.are.same("updated", items[1].comment)

      cleanup_manager(buf)
    end)
  end)

  describe("close_manager", function()
    it("closes manager buffer even when buffer has unsaved modifications", function()
      local buf = open_manager_with({
        {
          id = "close-1",
          file = "a.lua",
          line = 1,
          end_line = 1,
          comment = "original",
        },
      })

      -- Modify the buffer to make it 'modified' (unsaved changes)
      vim.api.nvim_buf_set_option(buf, "modifiable", true)
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "extra line" })

      -- Verify the buffer is modified
      assert.is_true(vim.api.nvim_buf_get_option(buf, "modified"))

      -- close_manager is called via <CR> keymap; simulate by calling open_manager
      -- which internally tracks manage_buf, then trigger close via <CR>
      -- Instead, directly test that bwipeout! works by pressing <CR> on a valid annotation
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)

      -- The buffer should no longer exist (wiped out without error)
      assert.is_true(not vim.api.nvim_buf_is_valid(buf))

      -- Cleanup stubs
      store.list:revert()
      store.reorder:revert()
      store.save:revert()
      if store.get.revert then
        store.get:revert()
      end
    end)
  end)
end)
