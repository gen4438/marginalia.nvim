local project = require("marginalia.utils.project")

describe("project.root", function()
  it("detects the project root correctly", function()
    local root = project.root()
    assert.truthy(root)
    assert.is_string(root)
    -- We assume the tests run inside marginalia.nvim repo
    -- assert.active_workspace_contains(root, "marginalia.nvim")
    -- note: `assert.active_workspace_contains` is not standard busted. Just check string match.
    assert.is_true(root:find("marginalia.nvim", 1, true) ~= nil)
  end)
end)
