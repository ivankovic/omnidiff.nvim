--  This file is part of the OmniDiff code diffing tool.
--
--  Copyright (C) 2026 Marko Ivankovic
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU Affero General Public License as published
--  by the Free Software Foundation, version 3 of the License.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU Affero General Public License for more details.
--
--  You should have received a copy of the GNU Affero General Public License
--  along with this program.  If not, see <https://www.gnu.org/licenses/>.

local M = {}

---@class OmniDiffConfig
---@field bin string Path to (or name of) the omnidiff binary, looked up on $PATH by default.
local defaults = {
  bin = "omnidiff",
}

M.config = vim.deepcopy(defaults)

---@param opts OmniDiffConfig|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

-- Highlight groups, linked (not hardcoded colors) to standard diff highlights so any colorscheme
-- that already styles DiffAdd/DiffDelete/DiffChange/DiffText looks right here with no extra work.
-- `default = true` means these never clobber a user's or colorscheme's own override.
local HIGHLIGHT_LINKS = {
  OmniDiffInsert = "DiffAdd",
  OmniDiffDelete = "DiffDelete",
  OmniDiffUpdate = "DiffChange",
  OmniDiffMove = "DiffText",
}

local function ensure_highlights()
  for name, link in pairs(HIGHLIGHT_LINKS) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
end

-- omnidiff's `--mode json` operation strings (see omnidiff's own `src/tui/json_output.rs`) map
-- 1:1 onto the highlight groups above. `identical`/unchanged text never appears in the JSON at
-- all, so there is no entry for it here.
local HIGHLIGHT_BY_OPERATION = {
  insert = "OmniDiffInsert",
  delete = "OmniDiffDelete",
  update = "OmniDiffUpdate",
  move = "OmniDiffMove",
}

-- Public so callers (and tests) can query or clear the marks this plugin owns without guessing
-- the name. Every extmark set here lives in this namespace and nothing else writes to it.
M.namespace = vim.api.nvim_create_namespace("omnidiff")
local NAMESPACE = M.namespace

---Paints one side's hunks as extmarks on `bufnr`.
---
---`range` is already 0-indexed row/col, and **its columns are byte offsets** - which is exactly
---what `nvim_buf_set_extmark` wants, so no translation is needed in either direction. That is not
---true of every editor: VS Code's `Position.character` is UTF-16 code units, so its integration
---has to convert per line. See omnidiff's `src/tui/json_output.rs` for the full note.
---
---Public so a caller can paint a buffer it already has open (and so the tests can read the marks
---back through `M.namespace`), rather than going through `open_diff`'s tab/split layout.
---@param bufnr integer
---@param hunks table[]
function M.render_hunks(bufnr, hunks)
  vim.api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)
  for _, hunk in ipairs(hunks) do
    local hl_group = HIGHLIGHT_BY_OPERATION[hunk.operation]
    if hl_group then
      local range = hunk.range
      vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, range.start_row, range.start_column, {
        end_row = range.end_row,
        end_col = range.end_column,
        hl_group = hl_group,
      })

      -- Only `move` hunks carry a real cross-file jump target - see json_output.rs's own
      -- doc comment on why every other operation's `destination` is a bookkeeping anchor, not a
      -- real position, and so is never exposed as `move_target` at all.
      if hunk.move_target then
        vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, range.start_row, 0, {
          virt_text = { { (" » moved to line %d"):format(hunk.move_target.start_row + 1), "Comment" } },
          virt_text_pos = "eol",
        })
      end
    end
  end
end

---Runs `omnidiff --mode json before after` and calls `on_done(diff)` with the decoded result.
---Notifies and returns (without calling `on_done`) on a missing binary, non-zero exit, or
---unparseable output - there is no partial/degraded diff to fall back to in any of those cases.
---@param before string
---@param after string
---@param on_done fun(diff: table)
local function run_diff(before, after, on_done)
  local bin = M.config.bin
  if vim.fn.executable(bin) == 0 then
    vim.notify(("omnidiff.nvim: `%s` not found on $PATH - see :checkhealth omnidiff"):format(bin), vim.log.levels.ERROR)
    return
  end

  vim.system({ bin, "--mode", "json", before, after }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify(
          ("omnidiff exited with code %d: %s"):format(result.code, vim.trim(result.stderr or "")),
          vim.log.levels.ERROR
        )
        return
      end

      local ok, diff = pcall(vim.json.decode, result.stdout)
      if not ok then
        vim.notify("omnidiff.nvim: failed to parse omnidiff's JSON output: " .. tostring(diff), vim.log.levels.ERROR)
        return
      end

      on_done(diff)
    end)
  end)
end

---Opens `before` and `after` in a new tab, side by side, and highlights their diff.
---@param before string
---@param after string
function M.open_diff(before, after)
  ensure_highlights()
  run_diff(before, after, function(diff)
    vim.cmd.tabnew(vim.fn.fnameescape(before))
    local before_buf = vim.api.nvim_get_current_buf()
    vim.cmd.vsplit(vim.fn.fnameescape(after))
    local after_buf = vim.api.nvim_get_current_buf()

    M.render_hunks(before_buf, diff.before.hunks)
    M.render_hunks(after_buf, diff.after.hunks)
  end)
end

---Diffs the current buffer's on-disk content against its unsaved edits, by writing the buffer's
---current lines to a temp file and diffing that against the real path. Order matters: `before` is
---the saved file (what's on disk), `after` is the temp file (what you're currently editing) - the
---same "old vs. new" convention `omnidiff`'s own CLI and `git difftool` use.
function M.diff_this()
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    vim.notify("omnidiff.nvim: current buffer has no file name", vim.log.levels.ERROR)
    return
  end
  if not vim.bo[bufnr].modified then
    vim.notify("omnidiff.nvim: buffer has no unsaved changes", vim.log.levels.INFO)
    return
  end

  local tmp = vim.fn.tempname() .. "_" .. vim.fn.fnamemodify(path, ":t")
  vim.fn.writefile(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), tmp)

  M.open_diff(path, tmp)
end

return M
