local gh = require("gh-actions.github")
local ui = require("gh-actions.ui")

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

function M.open()
  local repo = gh.get_current_repository()

  ui.open()
  ui.split:map("n", "q", M.close, { noremap = true })

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

function M.close()
  ui.close()
end

return M
