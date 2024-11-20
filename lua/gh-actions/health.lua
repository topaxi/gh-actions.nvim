local M = {}

function M.check()
  local health = vim.health

  health.start('Checking ability to parse yaml files')

  local has_native_module, native_module_error =
    pcall(require, 'gh_actions_native.yaml')

  if has_native_module then
    health.ok('Found native module')
  else
    health.warn('No native module found')
    health.error(native_module_error)
  end

  local has_yq_installed = vim.fn.executable('yq') == 1

  if has_yq_installed then
    health.ok('Found yq executable')
  else
    health.warn('No yq executable found')
  end

  if has_native_module or has_yq_installed then
    health.ok('Found yaml parser')
  else
    health.error('No yaml parser found')
  end

  require('gh-actions.providers.github.rest.health').check()
end

return M
