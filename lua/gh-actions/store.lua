local utils = require('gh-actions.utils')

---@class GhActionsStateWorkflowConfig
---@field last_read integer
---@field config table

---@class GhActionsState
---@field title string
---@field repo string
---@field server string
---@field pipelines pipeline.Pipeline[]
---@field runs table<integer | string, pipeline.Run[]>
---@field jobs table<integer | string, pipeline.Job[]>
---@field steps table<integer | string, pipeline.Step[]>
---@field workflow_configs table<integer, GhActionsStateWorkflowConfig>
local initialState = {
  title = 'pipeline.nvim',
  repo = '',
  server = '',
  pipelines = {},
  runs = {},
  jobs = {},
  workflow_configs = {},
}

---@class GhActionsStore
---@field package _state GhActionsState
---@field package _update fun(state: GhActionsState)[]
local M = {
  _state = initialState,
  _update = {},
}

---@param state GhActionsState
local function emit_update(state)
  for _, update in ipairs(M._update) do
    update(state)
  end
end

emit_update = utils.debounced(vim.schedule_wrap(emit_update))

---@param fn fun(render_state: GhActionsState): GhActionsState|nil
function M.update_state(fn)
  M._state = fn(M._state) or M._state

  emit_update(M._state)
end

---@param fn function<GhActionsState>
function M.on_update(fn)
  table.insert(M._update, fn)
end

---@param fn function<GhActionsState>
function M.off_update(fn)
  M._update = vim.tbl_filter(function(f)
    return f ~= fn
  end, M._update)
end

---@return GhActionsState
function M.get_state()
  return M._state
end

return M
