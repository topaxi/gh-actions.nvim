---@class GhActionsComponent
---@field protected super { init: fun(self: table, options: table) }
local Component = require('lualine.component'):extend()

---@class GhActionsComponentOptions
local default_options = {
  icon = '',
  ---@param component GhActionsComponent
  ---@param state GhActionsState
  ---@return string
  format = function(component, state)
    local latest_run = state.latest_run

    if not latest_run or not latest_run.status then
      return ''
    end

    return component.icons.get_workflow_run_icon(latest_run)
      .. ' '
      .. latest_run.name
  end,

  on_click = function()
    require('gh-actions').toggle()
  end,
}

---@override
---@param options GhActionsComponentOptions
function Component:init(options)
  self.options = vim.tbl_deep_extend('force', default_options, options or {})

  Component.super.init(self, self.options)

  self.store = require('gh-actions.store')
  self.icons = require('gh-actions.utils.icons')

  local server, repo = require('gh-actions.git').get_current_repository()

  if not server or not repo then
    return
  end

  require('gh-actions').start_polling()

  self.store.on_update(function()
    require('lualine').refresh()
  end)
end

---@override
function Component:update_status()
  return self.options.format(self, self.store.get_state())
end

return Component
