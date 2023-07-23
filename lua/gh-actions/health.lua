local health = vim.health or require('health')

local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error

local M = {}

function M.check()
  start('Checking ability to parse yaml files')

  local has_rust_module, _rust = pcall(require, 'gh-actions.rust')

  if has_rust_module then
    ok('Found rust module')
  else
    warn('No rust module found')
  end

  local has_yq_installed = vim.fn.executable('yq') == 1

  if has_yq_installed then
    ok('Found yq executable')
  else
    warn('No yq executable found')
  end

  if has_rust_module or has_yq_installed then
    ok('Found yaml parser')
  else
    error('No yaml parser found')
  end

  start('Checking for GitHub token')

  local k, token = pcall(require('gh-actions.github').get_github_token)

  if k and token then
    ok('Found GitHub token')
  else
    error('No GitHub token found')
  end
end

return M
