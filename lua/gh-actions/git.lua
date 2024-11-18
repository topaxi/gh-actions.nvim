local M = {}

---@param job Job
local function create_job(job)
  return require('plenary.job'):new(job)
end

function M.get_current_branch()
  local job = create_job {
    command = 'git',
    args = { 'branch', '--show-current' },
  }

  job:sync()

  return table.concat(job:result(), '')
end

function M.get_default_branch()
  local job = create_job {
    command = 'git',
    args = { 'remote', 'show', 'origin' },
  }

  job:sync()

  -- luacheck: ignore
  for match in table.concat(job:result(), ''):gmatch('HEAD branch: (%a+)') do
    return match
  end

  return 'main'
end

return M
