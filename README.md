# marginalia.nvim

Markdown Context Generator for Code.

Select code, add annotations, and generate Markdown context for AI prompts.

## Features

- **Annotate**: Select code in visual mode and add comments via a floating window.
- **Context Generation**: Automatically formats the selected code and your comment into Markdown with proper language syntax highlighting.
- **Clipboard Integration**: Copies the generated Markdown directly to your system clipboard (`+` register).
- **Project Scope**: Annotations are saved per project.
- **Quickfix Review**: View all annotations in the Quickfix list.
- **Management Buffer**: dedicated buffer to list and delete annotations.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "gen4438/marginalia.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("marginalia").setup({
      -- Optional configuration
      -- default_mappings = true, -- if you want <leader>ma
    })

    -- Recommended mapping
    vim.keymap.set("v", "<leader>ma", ":MarginaliaAnnotate<CR>", { desc = "Annotate Selection" })
    vim.keymap.set("n", "<leader>ml", ":MarginaliaList<CR>", { desc = "List Annotations" })
    vim.keymap.set("n", "<leader>mm", function() require("marginalia.ui.display").open_manager() end, { desc = "Manage Annotations" })
  end
}
```

## Usage

### 1. Annotate Code

1. Select a block of code in **Visual Mode**.
2. Run command `:MarginaliaAnnotate` (or use your keymapping).
3. A floating window will appear. Type your comment / annotation.
4. Press `<CR>` (Enter) in Normal mode to save.
   - The annotation is saved to disk.
   - A Markdown snippet is generated and copied to your clipboard.

**Example Output:**

```markdown
## Explanation of main function
File: `src/main.rs:10-15`

\`\`\`rust
fn main() {
  println!("Hello");
}
\`\`\`
```

### 2. Review Annotations

- Run `:MarginaliaList` to open the Quickfix list with all annotations for the current project.

### 3. Manage Annotations

- Run `:MarginaliaManage` (or the mapped Lua function) to open a management buffer.
- Press `dd` on a line to delete that annotation.
- Press `r` to refresh the list.
- Press `q` to close.

## Development

### Prerequisites

- **luacheck** (linter)
  - Install via luarocks: `luarocks install luacheck`
  - Or system package manager: `sudo apt install lua-check` (Ubuntu/Debian)
- **stylua** (formatter)
  - Install via cargo: `cargo install stylua`
- **pre-commit** (hook manager)
  - Install via pip: `pip install pre-commit`

### Setup

Install git hooks to automatically lint and format on commit:

```sh
make install-hooks
```

### Testing

Run tests with `make`:

```sh
make test
```

Lint code:

```sh
make lint
```

Format code:

```sh
make format
```
