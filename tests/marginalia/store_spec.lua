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
