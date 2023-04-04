local gh = require("gh-actions.github")
local ui = require("gh-actions.ui")

local M = {
  setup_called = false,
  init_root = "",
  refresh_interval = 10,
  timer = nil,
}

---@class GhActionsOptions
---@field refresh_interval? integer in seconds
---@field ui? GhActionsRenderOptions

---@param opts? GhActionsOptions
function M.setup(opts)
  opts = opts or {}

  M.init_root = vim.fn.getcwd()

  M.setup_called = true

  M.refresh_interval = opts.refresh_interval or M.refresh_interval

  ui.setup(opts.ui)

  vim.api.nvim_create_user_command("GhActions", M.open, {})
end

--TODO Only periodically fetch all workflows
--     then fetch runs for a single workflow (tabs/expandable)
--     Maybe periodically fetch all workflow runs to update
--     "toplevel" workflow states
--TODO Maybe send lsp progress events when fetching, to interact
--     with fidget.nvim
local function fetch_data()
  local repo = gh.get_current_repository()

  ui.update_state(function(state)
    state.repo = repo
  end)

  gh.get_workflows(repo, {
    callback = function(workflows)
      ui.update_state(function(state)
        state.workflows = workflows
      end)
    end,
  })

  gh.get_repository_workflow_runs(repo, 100, {
    callback = function(workflow_runs)
      ui.update_state(function(state)
        state.workflow_runs = workflow_runs
      end)
    end,
  })
end

function M.open()
  ui.open()
  ui.split:map("n", "q", M.close, { noremap = true })

  ui.split:map("n", "<cr>", function()
    local workflow = ui.get_workflow()
    local workflow_run = ui.get_workflow_run()

    if workflow then
      vim.notify(string.format("Workflow: %s", workflow.name))
    end
    if workflow_run then
      vim.notify(string.format("Workflow run: %s", workflow_run.head_commit.message))
    end
  end, { noremap = true })

  ui.split:map("n", "r", function()
    local workflow = ui.get_workflow()

    if workflow then
      gh.dispatch_workflow(ui.render_state.repo, workflow.id)
    end
  end, { noremap = true })

  M.timer = vim.loop.new_timer()
  M.timer:start(0, M.refresh_interval * 1000, vim.schedule_wrap(fetch_data))
end

function M.close()
  ui.close()
  M.timer:stop()
  M.timer:close()
  M.timer = nil
end

return M
