local Split = require("nui.split")
local utils = require("gh-actions.utils")

local split = Split({
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
  render_state = {
    repo = nil,
    workflows = {},
    workflow_runs = {},
  },
  icons = {
    conclusion = {
      success = "✓",
      failure = "X",
      cancelled = "⊘",
    },
    status = {
      pending = "●",
      requested = "●",
      waiting = "●",
      in_progress = "●",
    },
  },
}

---@param run GhWorkflowRun
---@return string
local function get_workflow_run_icon(run)
  if not run then
    return "?"
  end

  if run.status == "completed" then
    return M.icons.conclusion[run.conclusion] or run.conclusion
  end

  return M.icons.status[run.status] or "?"
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

local function renderTitle()
  if not M.render_state.repo then
    return { "Github Workflows", "" }
  end

  return { string.format("Github Workflows for %s", M.render_state.repo), "" }
end

---@param workflows GhWorkflow[]
---@param workflow_runs GhWorkflowRun[]
---@return table
local function renderWorkflows(workflows, workflow_runs)
  local lines = {}
  local workflow_runs_by_workflow_id = group_by_workflow(workflow_runs)

  for _, workflow in ipairs(workflows) do
    local runs = workflow_runs_by_workflow_id[workflow.id] or {}

    -- TODO Render ⚡️ or ✨ if workflow has workflow dispatch
    table.insert(lines, string.format("%s %s", get_workflow_run_icon(runs[1]), workflow.name))

    -- TODO cutting down on how many we list here, as we fetch 100 overall repo
    -- runs on opening the split. I guess we do want to have this configurable.
    for _, run in ipairs({ unpack(runs, 1, math.min(5, #runs)) }) do
      table.insert(
        lines,
        string.format("  %s %s", get_workflow_run_icon(run), run.head_commit.message:gsub("\n.*", ""))
      )
    end

    if #runs > 0 then
      table.insert(lines, "")
    end
  end

  return lines
end

local function is_visible()
  return split.bufnr ~= nil and vim.bo[split.bufnr] ~= nil
end

function M.render()
  if not is_visible() then
    return
  end

  vim.bo[split.bufnr].modifiable = true
  local lines = vim.tbl_flatten({
    renderTitle(),
    renderWorkflows(M.render_state.workflows, M.render_state.workflow_runs),
  })

  vim.api.nvim_buf_set_lines(split.bufnr, 0, -1, false, lines)
  vim.bo[split.bufnr].modifiable = false
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

---@class GhActionsRenderOptions
---@field icons? { conclusion?: table, status?: table }

---@param render_options? GhActionsRenderOptions
function M.setup(render_options)
  render_options = render_options or {}

  M.icons = vim.tbl_deep_extend("force", {}, M.icons, render_options.icons or {})
end

function M.open()
  split:mount()

  M.render()
end

function M.close()
  split:unmount()
end

return M
