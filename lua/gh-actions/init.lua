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

  for _, run in ipairs(runs) do
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
  if not run then
    return "?"
  end

  if run.status == "completed" then
    return conclusion_icon_map[run.conclusion] or run.conclusion
  end

  return status_icon_map[run.status] or "?"
end

---@param workflows GhWorkflow[]
---@param workflow_runs GhWorkflowRun[]
local function renderWorkflows(workflows, workflow_runs)
  local workflow_runs_by_workflow_id = group_by_workflow(workflow_runs)

  vim.api.nvim_buf_set_lines(split.bufnr, 0, 2, false, { "Github Workflows", "" })
  vim.api.nvim_buf_set_lines(split.bufnr, 2, -1, true, {})

  for _, workflow in ipairs(workflows) do
    local latestRun = (workflow_runs_by_workflow_id[workflow.id] or {})[1]

    vim.api.nvim_buf_set_lines(
      split.bufnr,
      -1,
      -1,
      true,
      { string.format("%s %s", get_workflow_run_icon(latestRun), workflow.name) }
    )

    for _, run in ipairs(workflow_runs_by_workflow_id[workflow.id] or {}) do
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

  local workflows = {}
  local workflow_runs = {}

  local render = function()
    renderWorkflows(workflows, workflow_runs)
  end

  gh.get_workflows(repo, {
    callback = vim.schedule_wrap(function(w)
      workflows = w

      render()

      gh.get_workflow_runs(repo, 20, {
        callback = vim.schedule_wrap(function(wr)
          workflow_runs = wr

          render()
        end),
      })
    end),
  })

  render()
end

function M.close()
  split:unmount()
end

return M
