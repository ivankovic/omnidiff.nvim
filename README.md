# omnidiff.nvim

[![CI](https://github.com/ivankovic/omnidiff.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/ivankovic/omnidiff.nvim/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0--only-blue)](LICENSE)

Syntax-aware diffing in Neovim, backed by the [omnidiff](https://github.com/ivankovic/omnidiff)
CLI. Renders `omnidiff --mode json`'s full-range-precision hunk data directly onto Neovim buffers
with extmarks, instead of parsing ANSI text out of a terminal diff tool.

## Requirements

* Neovim >= 0.10 (uses `vim.system()`).
* The [`omnidiff`](https://github.com/ivankovic/omnidiff) binary, on `$PATH` or pointed at
  explicitly (see Setup below), built with `--mode json` support.

Run `:checkhealth omnidiff` to confirm both are in place.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "ivankovic/omnidiff.nvim",
  opts = {},
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use({
  "ivankovic/omnidiff.nvim",
  config = function()
    require("omnidiff").setup()
  end,
})
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'ivankovic/omnidiff.nvim'
```
```lua
require('omnidiff').setup()
```

## Setup

```lua
require('omnidiff').setup({
  -- Path to (or name of) the omnidiff binary. Default: 'omnidiff'.
  bin = 'omnidiff',
})
```

`setup()` is optional - the default above is used if it's never called.

## Usage

* `:OmniDiff {before} {after}` - diff two files, opened side by side in a new tab.
* `:OmniDiffThis` - diff the current buffer's unsaved edits against the on-disk file.

## Highlights

Linked (not hardcoded) to standard diff highlights, so any colorscheme that already styles
`DiffAdd`/`DiffDelete`/`DiffChange`/`DiffText` looks right immediately:

| Group             | Linked to    |
|-------------------|--------------|
| `OmniDiffInsert`  | `DiffAdd`    |
| `OmniDiffDelete`  | `DiffDelete` |
| `OmniDiffUpdate`  | `DiffChange` |
| `OmniDiffMove`    | `DiffText`   |

## How it works

`omnidiff --mode json BEFORE AFTER` prints one JSON object describing each side's changed ranges,
their operation (insert/delete/update/move), a move's real counterpart range in the other file, and
the nearest enclosing declaration. This plugin places that directly onto your buffers as extmarks -
it never parses ANSI escapes out of a terminal diff tool.

**Its columns are byte offsets**, which is exactly what `nvim_buf_set_extmark` wants, so nothing is
translated in either direction. (That is not true everywhere: VS Code's `Position.character` is
UTF-16 code units and has to convert per line.) `tests/run.lua` pins this with a non-ASCII case, so
a change of convention on either side fails the suite rather than silently mis-highlighting.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: `stylua .`, `luacheck lua plugin tests`, and
`nvim -l tests/run.lua` - the same three things CI gates on.

## License

AGPL-3.0-only - see [LICENSE](LICENSE), the same licence as
[omnidiff](https://github.com/ivankovic/omnidiff) itself.
