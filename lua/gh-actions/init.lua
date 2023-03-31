local Split = require("nui.split")
local gh = require("gh-actions.github")

local split = Split({
  position = "right",
  size = 60,
  win_options = {
    number = false,
    --TODO Do we use folds or some custom "component"?
    foldlevel = 0,
    cursorcolumn = false,
  },
})

local M = {
  setup_called = false,
  init_root = "",
  refresh_interval = 10,
}

---@class GhActionsOptions
---@field refresh_interval integer in seconds

---@param opts? GhActionsOptions
function M.setup(opts)
  opts = opts or {}

  M.init_root = vim.fn.getcwd()

  M.setup_called = true

  M.refresh_interval = opts.refresh_interval or M.refresh_interval

  vim.api.nvim_create_user_command("GhActions", M.open, {})
end

---@param runs GhWorkflowRun[]
---@return table<number, GhWorkflowRun[]>
local function group_by_workflow(runs)
  local m = {}

  for _, run in pairs(runs) do
    m[run.workflow_id] = m[run.workflow_id] or {}
    table.insert(m[run.workflow_id], run)
  end

  return m
end

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
  if run.status == "completed" then
    return conclusion_icon_map[run.conclusion] or run.conclusion
  end

  return status_icon_map[run.status] or "?"
end

---@param workflows GhWorkflow[]
---@param workflow_runs GhWorkflowRun[]
local function renderWorkflows(workflows, workflow_runs)
  local workflow_runs_by_workflow_id = group_by_workflow(workflow_runs)

  vim.api.nvim_buf_set_lines(split.bufnr, 0, 0, false, { "Github Workflows" })

  for _, workflow in pairs(workflows) do
    vim.api.nvim_buf_set_lines(split.bufnr, -1, -1, true, { workflow.name })

    for _, run in pairs(workflow_runs_by_workflow_id[workflow.id] or {}) do
      vim.api.nvim_buf_set_lines(split.bufnr, -1, -1, true, {
        string.format("  %s %s", get_workflow_run_icon(run), run.head_commit.message:gsub("\n.*", "")),
      })
    end
  end
end

function M.open()
  split:mount()
  split:map("n", "q", M.close, { noremap = true })

  local repo = gh.get_current_repository()

  local workflows = gh.get_workflows(repo)
  local workflow_runs = gh.get_workflow_runs(repo)

  renderWorkflows(workflows, workflow_runs)
end

function M.close()
  split:unmount()
end

return M
