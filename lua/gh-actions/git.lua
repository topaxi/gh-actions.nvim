local job = require('plenary.job')

local M = {}

function M.get_current_branch()
  local gitJob = job:new {
    command = 'git',
    args = { 'branch', '--show-current' },
  }

  gitJob:sync()

  return table.concat(gitJob:result(), '')
end

function M.get_default_branch()
  local gitJob = job:new {
    command = 'git',
    args = { 'remote', 'show', 'origin' },
  }

  gitJob:sync()

  -- luacheck: ignore
  for match in table.concat(gitJob:result(), ''):gmatch('HEAD branch: (%a+)') do
    return match
  end

  return 'main'
end

return M
