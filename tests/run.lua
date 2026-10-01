--  This file is part of the OmniDiff code diffing tool.
--
--  Copyright (C) 2026 Marko Ivankovic
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU Affero General Public License as published
--  by the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU Affero General Public License for more details.
--
--  You should have received a copy of the GNU Affero General Public License
--  along with this program.  If not, see <https://www.gnu.org/licenses/>.

-- The whole test harness: `nvim -l tests/run.lua`, no plugin manager and no test framework to
-- install. plenary.nvim is the usual choice for a Neovim plugin, but it is a dependency to fetch
-- and pin in CI for what amounts to `assert` plus a runner - and these tests need a real Neovim
-- (buffers, extmarks), which `nvim -l` already gives us.
--
-- Exits non-zero on the first failure so CI fails loudly; prints every test either way.

dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/minimal_init.lua")

local failures = 0
local total = 0

---@param name string
---@param fn fun()
local function test(name, fn)
  total = total + 1
  local ok, err = pcall(fn)
  if ok then
    print(("  ok   %s"):format(name))
  else
    failures = failures + 1
    print(("  FAIL %s\n       %s"):format(name, tostring(err)))
  end
end

local function assert_eq(actual, expected, what)
  if not vim.deep_equal(actual, expected) then
    error(("%s: expected %s, got %s"):format(what or "value", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local omnidiff = require("omnidiff")

---A scratch buffer holding `lines`, for painting into.
local function buffer_with(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

---Every extmark this plugin owns in `bufnr`, as `{ row, col, end_row, end_col, hl_group }`.
local function marks_in(bufnr)
  local raw = vim.api.nvim_buf_get_extmarks(bufnr, omnidiff.namespace, 0, -1, { details = true })
  local out = {}
  for _, mark in ipairs(raw) do
    -- {id, row, col, details}
    local row, col, details = mark[2], mark[3], mark[4]
    if details.hl_group then
      table.insert(out, { row, col, details.end_row, details.end_col, details.hl_group })
    end
  end
  return out
end

print("omnidiff.nvim")

test("setup() defaults to looking omnidiff up on $PATH", function()
  omnidiff.setup()
  assert_eq(omnidiff.config.bin, "omnidiff", "config.bin")
end)

test("setup() overrides only what it is given", function()
  omnidiff.setup({ bin = "/opt/omnidiff" })
  assert_eq(omnidiff.config.bin, "/opt/omnidiff", "config.bin")
  omnidiff.setup() -- restore for the tests below
end)

test("each operation paints its own highlight group", function()
  local bufnr = buffer_with({ "alpha", "beta", "gamma", "delta" })
  omnidiff.render_hunks(bufnr, {
    { operation = "insert", range = { start_row = 0, start_column = 0, end_row = 0, end_column = 5 } },
    { operation = "delete", range = { start_row = 1, start_column = 0, end_row = 1, end_column = 4 } },
    { operation = "update", range = { start_row = 2, start_column = 0, end_row = 2, end_column = 5 } },
    { operation = "move", range = { start_row = 3, start_column = 0, end_row = 3, end_column = 5 } },
  })
  assert_eq(marks_in(bufnr), {
    { 0, 0, 0, 5, "OmniDiffInsert" },
    { 1, 0, 1, 4, "OmniDiffDelete" },
    { 2, 0, 2, 5, "OmniDiffUpdate" },
    { 3, 0, 3, 5, "OmniDiffMove" },
  }, "extmarks")
end)

test("an unknown operation is ignored rather than crashing", function()
  local bufnr = buffer_with({ "alpha" })
  omnidiff.render_hunks(bufnr, {
    { operation = "teleport", range = { start_row = 0, start_column = 0, end_row = 0, end_column = 5 } },
  })
  assert_eq(marks_in(bufnr), {}, "extmarks")
end)

-- The property that makes this integration correct at all: omnidiff reports **byte** columns and
-- nvim_buf_set_extmark takes byte columns, so a line with multi-byte characters needs no
-- conversion. If either side ever changed convention this is the test that would catch it.
test("byte columns pass through untranslated on a non-ASCII line", function()
  local line = 'x = "ααα" + bbb'
  local bufnr = buffer_with({ line })
  local byte_col = string.find(line, "bbb", 1, true) - 1 -- Lua is 1-indexed; extmarks are 0-indexed
  assert_eq(byte_col, 15, "byte offset of bbb")
  omnidiff.render_hunks(bufnr, {
    { operation = "update", range = { start_row = 0, start_column = byte_col, end_row = 0, end_column = byte_col + 3 } },
  })
  assert_eq(marks_in(bufnr), { { 0, 15, 0, 18, "OmniDiffUpdate" } }, "extmarks")
end)

test("re-rendering replaces the previous marks instead of stacking them", function()
  local bufnr = buffer_with({ "alpha", "beta" })
  local hunk = { operation = "insert", range = { start_row = 0, start_column = 0, end_row = 0, end_column = 5 } }
  omnidiff.render_hunks(bufnr, { hunk })
  omnidiff.render_hunks(bufnr, { hunk })
  assert_eq(#marks_in(bufnr), 1, "extmark count after a second render")
end)

test("a move hunk also gets its jump-target annotation", function()
  local bufnr = buffer_with({ "alpha", "beta" })
  omnidiff.render_hunks(bufnr, {
    {
      operation = "move",
      range = { start_row = 0, start_column = 0, end_row = 0, end_column = 5 },
      move_target = { start_row = 40, start_column = 0, end_row = 40, end_column = 5 },
    },
  })
  -- Indexing the tuple directly rather than unpack(): an extmark row is {id, row, col, details}
  -- and only `details` is wanted here.
  local all = vim.api.nvim_buf_get_extmarks(bufnr, omnidiff.namespace, 0, -1, { details = true })
  local annotations = {}
  for _, mark in ipairs(all) do
    local details = mark[4]
    if details.virt_text then
      table.insert(annotations, details.virt_text[1][1])
    end
  end
  -- 40 is 0-indexed in the JSON; users read 1-indexed line numbers.
  assert_eq(annotations, { " » moved to line 41" }, "move annotations")
end)

print(("\n%d test(s), %d failure(s)"):format(total, failures))
if failures > 0 then
  vim.cmd("cquit 1")
end
