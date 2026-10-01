# Contributing to omnidiff.nvim

This plugin is a thin client. It shells out to the [omnidiff](https://github.com/ivankovic/omnidiff)
binary and paints what comes back; almost every interesting decision about *what* a diff says lives
in that repository, not this one. Bugs about a diff being wrong belong there. Bugs about a
highlight landing in the wrong place, or a command misbehaving, belong here.

## Requirements

* Neovim >= 0.10 (the plugin uses `vim.system()`, and so does the test harness).
* [stylua](https://github.com/JohnnyMorganz/StyLua) and
  [luacheck](https://github.com/lunarmodules/luacheck) for the two lint gates.
* An `omnidiff` binary on `$PATH` for manual testing. The automated tests do not need one - they
  drive `render_hunks` with literal hunk tables rather than running the real thing.

## The three checks CI gates on

```sh
stylua --check .              # formatting; `stylua .` to fix
luacheck lua plugin tests     # lint
nvim -l tests/run.lua         # tests
```

Run all three before opening a pull request. They are the same commands
[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs, so there is nothing to keep in sync by
hand.

## Tests

`tests/run.lua` is the entire harness: `nvim -l` runs it as a Lua script with a real editor behind
it, so tests get genuine buffers and extmarks. There is deliberately no plenary.nvim or busted
dependency - what those buy over `pcall` plus a counter is not worth a pinned dependency in CI.

Add a test by calling `test("name", function() ... end)` in that file. `assert_eq` compares with
`vim.deep_equal` and prints both sides on failure. The runner exits non-zero on the first failure
and prints every test either way.

Two properties in there are load-bearing rather than incidental, and should not be deleted if they
become inconvenient:

* **Byte columns pass through untranslated.** omnidiff reports byte offsets and
  `nvim_buf_set_extmark` takes byte offsets. The non-ASCII test is what would catch either side
  changing convention - the failure mode otherwise is every highlight on a line containing a
  multi-byte character landing somewhere else, which nothing else here would notice.
* **An unknown operation is ignored rather than crashing.** omnidiff may add an operation this
  plugin does not know; a released plugin must degrade to "paints less" rather than to an error on
  every diff.

## Style

* `.stylua.toml` owns formatting: 2-space indent, 120 columns, double quotes. Do not hand-format
  against it.
* Comments explain *why*, not *what*. The main omnidiff repository's
  [`CONTRIBUTING.md`](https://github.com/ivankovic/omnidiff/blob/main/CONTRIBUTING.md) sets the
  house style and it applies here too.
* Every Lua file carries the AGPL header. Copy it from an existing file when adding a new one.

## Licence

By contributing you agree that your contributions are licensed under AGPL-3.0-or-later, the same
licence as [`LICENSE`](LICENSE) and as omnidiff itself.
