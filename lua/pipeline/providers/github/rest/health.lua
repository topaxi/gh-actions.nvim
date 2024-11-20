local M = {}

function M.check()
  local health = vim.health

  health.start('Github REST provider')

  local k, token =
    pcall(require('pipeline.providers.github.utils').get_github_token)

  if k and token then
    health.ok('Found GitHub token')
  else
    health.error('No GitHub token found')
  end
end

return M
