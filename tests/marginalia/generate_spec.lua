local generate = require("marginalia.core.generate")

describe("generate", function()
  it("formats annotation as markdown without code block by default", function()
    local item = {
      file = "src/main.rs",
      line = 10,
      end_line = 15,
      code_chunk = 'fn main() {\n  println!("Hello");\n}',
      comment = "Explanation of main function",
    }

    local md = generate.markdown(item)

    assert.is_string(md)
    assert.truthy(md:find("Explanation of main function", 1, true))
    assert.truthy(md:find("@src/main.rs#10%-15", 1))
    assert.falsy(md:find("```rust")) -- No code block by default
    assert.falsy(md:find("fn main", 1, true))
  end)

  it("includes code block when include_code is true", function()
    local item = {
      file = "src/main.rs",
      line = 10,
      end_line = 15,
      code_chunk = 'fn main() {\n  println!("Hello");\n}',
      comment = "Explanation of main function",
    }

    local md = generate.markdown(item, { include_code = true })

    assert.is_string(md)
    assert.truthy(md:find("Explanation of main function", 1, true))
    assert.truthy(md:find("@src/main.rs#10%-15", 1))
    assert.truthy(md:find("```rust"))
    assert.truthy(md:find("fn main", 1, true))
  end)
end)
