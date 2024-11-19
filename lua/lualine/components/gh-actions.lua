local function gh()
  return require('gh-actions.providers.github.rest._api')
end

local component = require('lualine.component'):extend()

---@class GhActionsComponent
local default_options = {
  icon = '',
}

---@override
---@param options GhActionsComponent
function component:init(options)
  component.super.init(self, options)

  self.options = vim.tbl_deep_extend('force', default_options, options or {})
  self.store = require('gh-actions.store')
  self.icons = require('gh-actions.utils.icons')

  local server, repo = gh().get_current_repository()

  if not server or not repo then
    return
  end

  require('gh-actions').start_polling()

  self.store.on_update(function()
    require('lualine').refresh()
  end)
end

---@override
function component:update_status()
  local state = self.store.get_state()

  local latest_workflow_run = state.workflow_runs and state.workflow_runs[1]
      or {}

  if not latest_workflow_run.status then
    return ''
  end

  return self.icons.get_workflow_run_icon(latest_workflow_run)
      .. ' '
      .. latest_workflow_run.name
end

return component
