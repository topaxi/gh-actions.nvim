local Split = require("nui.split")
local store = require("gh-actions.store")
local Render = require("gh-actions.ui.render")

local render = Render.new(store)

local split = Split({
  relative = "editor",
  position = "right",
  size = 60,
  win_options = {
    wrap = false,
    number = false,
    foldlevel = nil,
    foldcolumn = "0",
    cursorcolumn = false,
    signcolumn = "no",
  },
})

local M = {
  split = split,
  ---TODO Move highlights to config module
  highlights = {
    GhActionsRunIconSuccess = { link = "LspDiagnosticsVirtualTextHint" },
    GhActionsRunIconFailure = { link = "LspDiagnosticsVirtualTextError" },
    GhActionsRunIconStartup_failure = { link = "LspDiagnosticsVirtualTextError" },
    GhActionsRunIconPending = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconRequested = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconWaiting = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconIn_progress = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconCancelled = { link = "Comment" },
    GhActionsRunIconSkipped = { link = "Comment" },
    GhActionsRunCancelled = { link = "Comment" },
    GhActionsRunSkipped = { link = "Comment" },
    GhActionsJobCancelled = { link = "Comment" },
    GhActionsJobSkipped = { link = "Comment" },
    GhActionsStepCancelled = { link = "Comment" },
    GhActionsStepSkipped = { link = "Comment" },
  },
}

local function get_cursor_line(line)
  return line or vim.api.nvim_win_get_cursor(split.winid)[1]
end

---TODO: This should be a local function
---@param line? integer
---@return GhWorkflow|nil
function M.get_workflow(line)
  line = get_cursor_line(line)

  for _, loc in ipairs(render.locations) do
    if loc.kind == "workflow" and line >= loc.from and line <= loc.to then
      return loc.value
    end
  end
end

---TODO: This should be a local function
---@param line? integer
---@return GhWorkflowRun|nil
function M.get_workflow_run(line)
  line = get_cursor_line(line)

  for _, loc in ipairs(render.locations) do
    if loc.kind == "workflow_run" and line >= loc.from and line <= loc.to then
      return loc.value
    end
  end
end

local function is_visible()
  return split.bufnr ~= nil and vim.bo[split.bufnr] ~= nil
end

function M.render()
  M.locations = {}

  if not is_visible() then
    return
  end

  vim.bo[split.bufnr].modifiable = true

  render:render(split.bufnr)

  vim.bo[split.bufnr].modifiable = false
end

function M.setup()
  for hl_group, hl_group_value in pairs(M.highlights) do
    vim.api.nvim_set_hl(0, hl_group, hl_group_value)
  end
end

function M.open()
  split:mount()

  store.on_update(M.render)
  M.render()
end

function M.close()
  split:unmount()
  store.off_update(M.render)
end

return M
