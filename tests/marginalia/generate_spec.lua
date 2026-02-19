local generate = require("marginalia.core.generate")

describe("generate", function()
  it("formats annotation as markdown", function()
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
    assert.truthy(md:find("src/main.rs:10%-15"))
    assert.truthy(md:find("```rust")) -- Check if extension is inferred (rs -> rust)
    assert.truthy(md:find("fn main", 1, true))
  end)
end)
