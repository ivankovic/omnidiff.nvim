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

if vim.g.loaded_omnidiff then
  return
end
vim.g.loaded_omnidiff = true

vim.api.nvim_create_user_command("OmniDiff", function(opts)
  local args = opts.fargs
  if #args ~= 2 then
    vim.notify("OmniDiff needs exactly two file arguments: :OmniDiff {before} {after}", vim.log.levels.ERROR)
    return
  end
  require("omnidiff").open_diff(args[1], args[2])
end, {
  nargs = "+",
  complete = "file",
  desc = "Diff two files with omnidiff",
})

vim.api.nvim_create_user_command("OmniDiffThis", function()
  require("omnidiff").diff_this()
end, {
  desc = "Diff the current buffer's unsaved changes against the on-disk file with omnidiff",
})
