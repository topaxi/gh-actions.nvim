local Split = require('nui.split')
local Config = require('gh-actions.config')
local store = require('gh-actions.store')
local Render = require('gh-actions.ui.render')

local M = {
  split = nil,
  renderer = nil,
}

local function get_cursor_line(line)
  return line or vim.api.nvim_win_get_cursor(M.split.winid)[1]
end

---TODO: This should be a local function
---@param line? integer
---@return GhWorkflow|nil
function M.get_workflow(line)
  line = get_cursor_line(line)

  return M.renderer:get_location('workflow', line)
end

---TODO: This should be a local function
---@param line? integer
---@return GhWorkflowRun|nil
function M.get_workflow_run(line)
  line = get_cursor_line(line)

  return M.renderer:get_location('workflow_run', line)
end

---TODO: This should be a local function
---@param line? integer
---@return GhWorkflowRunJob|nil
function M.get_workflow_job(line)
  line = get_cursor_line(line)

  return M.renderer:get_location('workflow_job', line)
end

local function is_visible()
  return M.split.bufnr ~= nil and vim.bo[M.split.bufnr] ~= nil
end

function M.render()
  M.locations = {}

  if not is_visible() then
    return
  end

  vim.bo[M.split.bufnr].modifiable = true

  M.renderer:render(M.split.bufnr)

  vim.bo[M.split.bufnr].modifiable = false
end

function M.setup()
  M.split = Split(Config.options.split)
  M.renderer = Render.new(store)

  for hl_group, hl_group_value in pairs(Config.options.highlights) do
    vim.api.nvim_set_hl(0, hl_group, hl_group_value)
  end
end

function M.open()
  M.split:mount()

  store.on_update(M.render)
  M.render()
end

function M.close()
  M.split:unmount()
  store.off_update(M.render)
end

return M
