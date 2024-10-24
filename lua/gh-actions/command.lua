local M = {}

function handle_gh_actions_command(a)
  local gha = require('gh-actions')

  local action = a.fargs[1] or 'toggle'

  if action == 'open' then
    return gha.open()
  elseif action == 'close' then
    return gha.close()
  elseif action == 'toggle' then
    local ui = require('gh-actions.ui')

    if ui.split.winid then
      return gha.close()
    else
      return gha.open()
    end
  end
end

function completion_customlist()
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
