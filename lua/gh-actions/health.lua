local M = {}

function M.check()
  local health = vim.health

  health.start('Checking ability to parse yaml files')

  local has_rust_module = pcall(require, 'gh-actions.rust')

  if has_rust_module then
    health.ok('Found rust module')
  else
    health.warn('No rust module found')
  end

  local has_yq_installed = vim.fn.executable('yq') == 1

  if has_yq_installed then
    health.ok('Found yq executable')
  else
    health.warn('No yq executable found')
  end

  if has_rust_module or has_yq_installed then
    health.ok('Found yaml parser')
  else
    health.error('No yaml parser found')
  end

  require('gh-actions.providers.github.rest.health').check()
end

return M
