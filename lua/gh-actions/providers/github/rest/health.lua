local M = {}

function M.check()
  local health = vim.health

  health.start('Checking for GitHub token')

  local k, token =
    pcall(require('gh-actions.providers.github.rest._api').get_github_token)

  if k and token then
    health.ok('Found GitHub token')
  else
    health.error('No GitHub token found')
  end
end

return M
