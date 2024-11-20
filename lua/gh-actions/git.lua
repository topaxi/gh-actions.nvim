local M = {}

---@param job Job
local function create_job(job)
  return require('plenary.job'):new(job)
end

---@param str string
---@return string
local function strip_git_suffix(str)
  if str:sub(-4) == '.git' then
    return str:sub(1, -5)
  end

  return str
end

---@return string, string
---@nodiscard
function M.get_current_repository()
  local origin_url_job = create_job {
    command = 'git',
    args = {
      'config',
      '--get',
      'remote.origin.url',
    },
  }

  origin_url_job:sync()

  local origin_url = table.concat(origin_url_job:result(), '')

  local server, repo =
    strip_git_suffix(origin_url):match('([^@/:]+)[:/]([^/]+/[^/]+)$')

  return server, repo
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
