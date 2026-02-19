# marginalia.nvim

Markdown Context Generator for Code.

Select code, add annotations, and generate Markdown context for AI prompts.

## Features

- **Annotate**: Select code in visual mode and add comments via a floating window.
- **Context Generation**: Automatically formats the selected code and your comment into Markdown.
- **Clipboard Integration**: Copies the generated Markdown directly to your system clipboard (`+` register).
- **Project Scope**: Annotations are saved per project.
- **Quickfix Review**: View all annotations in the Quickfix list.
- **Management Buffer**: Dedicated buffer to list, open, and delete annotations.
- **fzf-lua Integration**: Fuzzy search annotations (requires [fzf-lua](https://github.com/ibhagwan/fzf-lua)).

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "gen4438/marginalia.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("marginalia").setup({
      -- include_code = true, -- Include code block in generated Markdown (default: false)
      -- textobject = "a",    -- Character for text objects/navigation: ia, aa, ]a, [a
      keymaps = {
        -- annotate = "<leader>ma", -- Visual + Normal mode (default)
        -- list     = "<leader>ml", -- Normal mode (default)
        -- manager  = "<leader>mm", -- Normal mode (default)
        -- search   = "<leader>ms", -- Normal mode (default)
      },
    })
  end
}
```

## Usage

### 1. Annotate Code

1. Select a block of code in **Visual Mode**, or place your cursor on a line in **Normal Mode**.
2. Run `:MarginaliaAnnotate` (visual) or `:MarginaliaAnnotateLine` (normal), or use your keymapping.
3. A floating window will appear. Type your comment / annotation.
4. Press `<CR>` (Enter) in Normal mode to save.
   - The annotation is saved to disk.
   - A Markdown snippet is generated and copied to your clipboard.

**Example Output (default):**

```markdown
@src/main.rs#10-15

Explanation of main function
```

**With `include_code = true`:**

```markdown
@src/main.rs#10-15

\`\`\`rust
fn main() {
  println!("Hello");
}
\`\`\`

Explanation of main function
```

### 2. Review Annotations

- `:MarginaliaList` - Open the Quickfix list with all annotations.

### 3. Manage Annotations

- `:MarginaliaManager` - Open an editable management buffer.
  - By default, annotations are displayed in a **folded summary view** (one line per annotation).
  - Use standard Vim fold commands to toggle between summary and expanded (full Markdown) views.

**Fold Controls:**

| Key | Action |
|-----|--------|
| `za` | Toggle fold for the annotation under cursor |
| `zR` | Expand all annotations (show code + full comments) |
| `zM` | Collapse all annotations (summary view) |

**Navigation & Selection:**

| Key | Action |
|-----|--------|
| `]a` | Jump to next annotation (supports count: `3]a`) |
| `[a` | Jump to previous annotation |
| `via` | Select inner annotation (code + comment, excluding header) |
| `vaa` | Select entire annotation block (including header) |

**Editing:**

| Key | Action |
|-----|--------|
| `dd` on header line (`@file#...`) | Delete the entire annotation block |
| `dd` on comment/code line | Delete that line only (normal editing) |
| `daa` | Delete entire annotation block |
| `<CR>` | Open the file and visually select the annotated range |
| `q` | Save changes and close |
| `:w` | Save changes without closing |

Text objects `ia` / `aa` work with all operators: `dia`, `yaa`, `cia`, etc.

### 4. Search Annotations

- `:MarginaliaSearch` - Fuzzy search annotations with fzf-lua.
  - Requires [fzf-lua](https://github.com/ibhagwan/fzf-lua) to be installed.

## Commands

| Command | Description |
|---|---|
| `:MarginaliaAnnotate` | Annotate selected code (visual mode) |
| `:MarginaliaAnnotateLine` | Annotate current line (normal mode) |
| `:MarginaliaList` | Open quickfix list with annotations |
| `:MarginaliaManager` | Open annotation manager buffer |
| `:MarginaliaSearch` | Fuzzy search annotations (fzf-lua) |

## API

```lua
local marginalia = require("marginalia")

marginalia.annotate()      -- Annotate current visual selection
marginalia.annotate_line() -- Annotate current line
marginalia.open_list()     -- Open quickfix list
marginalia.open_manager()  -- Open manager buffer
marginalia.search()        -- Fuzzy search with fzf-lua
```

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
