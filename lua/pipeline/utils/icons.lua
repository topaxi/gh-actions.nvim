local function Config()
  return require('pipeline.config')
end

local M = {}

---@return pipeline.config.Icons
function M.get_icons()
  return Config().options.icons
end

---@param run { status: string, conclusion: string }
---@return string
function M.get_workflow_run_icon(run)
  local icons = M.get_icons()

  if not run then
    return icons.status.unknown
  end

  if run.status == 'completed' then
    return icons.conclusion[run.conclusion] or run.conclusion
  end

  return icons.status[run.status] or icons.status.unknown
end

return M
