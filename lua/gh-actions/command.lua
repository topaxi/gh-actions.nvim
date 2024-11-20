local M = {}

local function handle_gh_actions_command(a)
  local gha = require('gh-actions')

  local action = a.fargs[1] or 'toggle'

  if action == 'open' then
    return gha.open()
  elseif action == 'close' then
    return gha.close()
  elseif action == 'toggle' then
    return gha.toggle()
  end
end

local function completion_customlist()
  return {
    'open',
    'close',
    'toggle',
  }
end

function M.setup()
  vim.api.nvim_create_user_command('GhActions', handle_gh_actions_command, {
    nargs = '?',
    complete = completion_customlist,
  })
end

return M
