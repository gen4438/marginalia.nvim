local store = require("marginalia.core.store")
local project = require("marginalia.utils.project")
local Path = require("plenary.path")

describe("store", function()
  local old_root = project.root
  local test_data_dir = "/tmp/marginalia_test_data"

  before_each(function()
    -- Mock project root to a fixed path for testing
    project.root = function()
      return "/tmp/mock_project"
    end

    -- Clean up test data
    local p = Path:new(test_data_dir)
    if p:exists() then
      p:rm({ recursive = true })
    end

    -- Setup store with test data dir
    store.setup({ data_dir = test_data_dir })
    -- We assume setup or a helper cleans internal state
    if store._reset then
      store._reset()
    end
  end)

  after_each(function()
    project.root = old_root
  end)

  it("can add and list annotations", function()
    local snippet = {
      file = "test.lua",
      line = 10,
      end_line = 12,
      comment = "Important logic",
      code_chunk = "local foo = bar",
    }
    store.add(snippet)

    local items = store.list()
    assert.are.same(1, #items)
    assert.are.same("Important logic", items[1].comment)
    assert.are.same("test.lua", items[1].file)
  end)

  describe("sort", function()
    it("sorts annotations by file path then line number (default)", function()
      store.add({ file = "c.lua", line = 5, end_line = 5, comment = "third" })
      store.add({ file = "a.lua", line = 10, end_line = 10, comment = "first" })
      store.add({ file = "b.lua", line = 1, end_line = 1, comment = "second" })

      store.sort()

      local items = store.list()
      assert.are.same("a.lua", items[1].file)
      assert.are.same("b.lua", items[2].file)
      assert.are.same("c.lua", items[3].file)
    end)

    it("sorts same file by line number", function()
      store.add({ file = "a.lua", line = 20, end_line = 25, comment = "second" })
      store.add({ file = "a.lua", line = 5, end_line = 10, comment = "first" })
      store.add({ file = "a.lua", line = 100, end_line = 105, comment = "third" })

      store.sort()

      local items = store.list()
      assert.are.same(5, items[1].line)
      assert.are.same(20, items[2].line)
      assert.are.same(100, items[3].line)
    end)

    it("sorts in reverse with '!'", function()
      store.add({ file = "a.lua", line = 1, end_line = 1, comment = "first" })
      store.add({ file = "c.lua", line = 1, end_line = 1, comment = "third" })
      store.add({ file = "b.lua", line = 1, end_line = 1, comment = "second" })

      store.sort("!")

      local items = store.list()
      assert.are.same("c.lua", items[1].file)
      assert.are.same("b.lua", items[2].file)
      assert.are.same("a.lua", items[3].file)
    end)

    it("sorts numerically with 'n'", function()
      store.add({ file = "a.lua", line = 100, end_line = 100, comment = "hundred" })
      store.add({ file = "a.lua", line = 2, end_line = 2, comment = "two" })
      store.add({ file = "a.lua", line = 20, end_line = 20, comment = "twenty" })

      store.sort("n")

      local items = store.list()
      -- Numeric sort on first number in line: the header is @a.lua#N
      -- so the first number encountered is the line number
      assert.are.same(2, items[1].line)
      assert.are.same(20, items[2].line)
      assert.are.same(100, items[3].line)
    end)

    it("handles single annotation without error", function()
      store.add({ file = "only.lua", line = 1, end_line = 1, comment = "only" })
      store.sort()
      assert.are.same(1, #store.list())
      assert.are.same("only.lua", store.list()[1].file)
    end)

    it("handles empty annotations without error", function()
      store.sort()
      assert.are.same(0, #store.list())
    end)
  end)

  it("persists annotations to disk", function()
    local snippet = {
      file = "test.lua",
      comment = "Persisted comment",
    }
    store.add(snippet)
    store.save()

    -- Reset internal state to simulate restart
    store._reset()
    assert.are.same(0, #store.list())

    -- Load from disk
    store.load()
    local items = store.list()
    assert.are.same(1, #items)
    assert.are.same("Persisted comment", items[1].comment)
  end)
end)
