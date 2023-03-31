local job = require("plenary.job")

local M = {}

---@param s string
local function trim(s)
  return s:match("^()%s*$") and "" or s:match("^%s*(.*%S)")
end

function M.get_current_branch()
  local gitJob = job:new({
    command = "git",
    args = { "branch", "--show-current" },
  })

  gitJob:sync()

  -- TOOD: Do we need to trim?
  return trim(table.concat(gitJob:result(), ""))
end

return M
