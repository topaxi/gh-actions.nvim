local Split = require("nui.split")
local utils = require("gh-actions.utils")

local split = Split({
  position = "right",
  size = 60,
  win_options = {
    number = false,
    foldlevel = nil,
    foldcolumn = "0",
    cursorcolumn = false,
    signcolumn = "no",
  },
})

local M = {
  split = split,
  render_state = {
    workflows = {},
    workflow_runs = {},
  },
}

local conclusion_icon_map = {
  success = "✓",
  failure = "X",
}

local status_icon_map = {
  pending = "●",
  requested = "●",
  waiting = "●",
  in_progress = "●",
}

---@param run GhWorkflowRun
---@return string
local function get_workflow_run_icon(run)
  if not run then
    return "?"
  end

  if run.status == "completed" then
    return conclusion_icon_map[run.conclusion] or run.conclusion
  end

  return status_icon_map[run.status] or "?"
end

---@param runs GhWorkflowRun[]
---@return table<number, GhWorkflowRun[]>
local function group_by_workflow(runs)
  local m = {}

  for _, run in ipairs(runs) do
    m[run.workflow_id] = m[run.workflow_id] or {}
    table.insert(m[run.workflow_id], run)
  end

  return m
end

---@param workflows GhWorkflow[]
---@param workflow_runs GhWorkflowRun[]
local function renderWorkflows(workflows, workflow_runs)
  local workflow_runs_by_workflow_id = group_by_workflow(workflow_runs)

  vim.api.nvim_buf_set_lines(split.bufnr, 0, 2, false, { "Github Workflows", "" })
  vim.api.nvim_buf_set_lines(split.bufnr, 2, -1, true, {})

  for _, workflow in ipairs(workflows) do
    local runs = workflow_runs_by_workflow_id[workflow.id] or {}

    vim.api.nvim_buf_set_lines(
      split.bufnr,
      -1,
      -1,
      true,
      -- TODO Render ⚡️ if workflow has workflow dispatch
      { string.format("%s %s", get_workflow_run_icon(runs[1]), workflow.name) }
    )

    -- TODO cutting down on how many we list here, as we fetch 100 overall repo
    -- runs on opening the split. I guess we do want to have this configurable.
    for _, run in ipairs({ unpack(runs, 1, math.min(5, #runs)) }) do
      vim.api.nvim_buf_set_lines(split.bufnr, -1, -1, true, {
        string.format("  %s %s", get_workflow_run_icon(run), run.head_commit.message:gsub("\n.*", "")),
      })
    end

    if #runs > 0 then
      vim.api.nvim_buf_set_lines(split.bufnr, -1, -1, true, { "" })
    end
  end
end

function M.render()
  renderWorkflows(M.render_state.workflows, M.render_state.workflow_runs)
end

M.render = utils.debounced(vim.schedule_wrap(M.render))

---@class GhActionsRenderState
---@field workflows GhWorkflow[]
---@field workflow_runs GhWorkflowRun[]

---@param fn fun(render_state: GhActionsRenderState): GhActionsRenderState|nil
function M.update_state(fn)
  M.render_state = fn(M.render_state) or M.render_state

  M.render()
end

function M.open()
  split:mount()

  M.render()
end

function M.close()
  split:unmount()
end

return M
