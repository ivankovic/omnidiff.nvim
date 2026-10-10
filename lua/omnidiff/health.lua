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

function M.check()
  vim.health.start("omnidiff.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim >= 0.10 found (needed for vim.system)")
  else
    vim.health.error("Neovim >= 0.10 is required (omnidiff.nvim uses vim.system)")
  end

  local bin = require("omnidiff").config.bin

  if vim.fn.executable(bin) == 0 then
    vim.health.error(("`%s` not found on $PATH"):format(bin), {
      "Install omnidiff: https://github.com/ivankovic/omnidiff#installation",
      "Or point omnidiff.nvim at it: require('omnidiff').setup({ bin = '/path/to/omnidiff' })",
    })
    return
  end
  vim.health.ok(("found `%s` on $PATH"):format(bin))

  -- Best-effort only: `--help` doesn't need real files, so this confirms the installed binary
  -- recognizes `--mode json` at all without needing a real diff to run. A missing/older omnidiff
  -- build (from before json_output.rs existed) is the main thing this is meant to catch.
  local result = vim.system({ bin, "--help" }, { text = true }):wait()
  if result.code == 0 and result.stdout:lower():find("json", 1, true) then
    vim.health.ok("installed omnidiff appears to support `--mode json`")
  else
    vim.health.warn("could not confirm `--mode json` support - you may need a newer omnidiff build")
  end
end

return M
