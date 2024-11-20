local M = {}

function M.check()
  local health = vim.health

  health.start('Gitlab GraphQL provider')

  if vim.fn.executable('glab') then
    health.ok('Found glab cli')
  else
    health.error('glab cli not found')
  end
end

return M
