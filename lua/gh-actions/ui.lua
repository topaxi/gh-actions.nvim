local store = require('gh-actions.store')

local M = {
  ---@type NuiSplit
  split = nil,
  ---@type GhActionsRender
  renderer = nil,
}

local function get_cursor_line(line)
  return line or vim.api.nvim_win_get_cursor(M.split.winid)[1]
end

---@param kind GhActionsRenderLocationKind
---@param line? integer
local function get_location(kind, line)
  line = get_cursor_line(line)

  return M.renderer:get_location(kind, line)
end

---@param line? integer
---@return pipeline.Pipeline|nil
function M.get_pipeline(line)
  return get_location('pipeline', line)
end

---@param line? integer
---@return pipeline.Run|nil
function M.get_run(line)
  return get_location('run', line)
end

---@param line? integer
---@return pipeline.Job|nil
function M.get_job(line)
  return get_location('job', line)
end

---@param line? integer
---@return pipeline.Step|nil
function M.get_step(line)
  return get_location('step', line)
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
  local Split = require('nui.split')
  local Config = require('gh-actions.config')
  local Render = require('gh-actions.ui.render')

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
