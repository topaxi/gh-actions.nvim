local Config = require('gh-actions.config')
local store = require('gh-actions.store')
local git = require('gh-actions.git')
local gh = require('gh-actions.github')
local ui = require('gh-actions.ui')
local utils = require('gh-actions.utils')

local M = {
  setup_called = false,
  init_root = '',
  timer = nil,
}

---@param opts? GhActionsConfig
function M.setup(opts)
  opts = opts or {}

  M.init_root = vim.fn.getcwd()

  M.setup_called = true

  Config.setup(opts)
  ui.setup()

  vim.api.nvim_create_user_command('GhActions', M.open, {})
end

--TODO Only periodically fetch all workflows
--     then fetch runs for a single workflow (tabs/expandable)
--     Maybe periodically fetch all workflow runs to update
--     "toplevel" workflow states
--TODO Maybe send lsp progress events when fetching, to interact
--     with fidget.nvim
local function fetch_data()
  local repo = gh.get_current_repository()

  store.update_state(function(state)
    state.repo = repo
  end)

  gh.get_workflows(repo, {
    callback = function(workflows)
      store.update_state(function(state)
        state.workflows = workflows
      end)
    end,
  })

  gh.get_repository_workflow_runs(repo, 100, {
    callback = function(workflow_runs)
      local old_workflow_runs = store.get_state().workflow_runs

      store.update_state(function(state)
        state.workflow_runs = workflow_runs
      end)

      local running_workflows = utils.uniq(
        function(run)
          return run.id
        end,
        vim.tbl_filter(function(run)
          return run.status ~= 'completed' and run.status ~= 'skipped'
        end, { unpack(old_workflow_runs), unpack(workflow_runs) })
      )

      for _, run in ipairs(running_workflows) do
        gh.get_workflow_run_jobs(repo, run.id, 20, {
          callback = function(jobs)
            store.update_state(function(state)
              state.workflow_jobs[run.id] = jobs
            end)
          end,
        })
      end
    end,
  })
end

local function now()
  local date = os.date('!*t')
  ---@cast date osdate
  return os.time(date)
end

local WORKFLOW_CONFIG_CACHE_TTL_S = 10

---TODO We should run this after fetching the workflows instead of within the state update event
---@param state GhActionsState
function M.update_workflow_configs(state)
  local n = now()

  for _, workflow in ipairs(state.workflows) do
    if
      not state.workflow_configs[workflow.id]
      or (n - state.workflow_configs[workflow.id].last_read)
        > WORKFLOW_CONFIG_CACHE_TTL_S
    then
      state.workflow_configs[workflow.id] = {
        last_read = n,
        config = gh.get_workflow_config(workflow.path),
      }
    end
  end
end

function M.open()
  ui.open()
  ui.split:map('n', 'q', M.close, { noremap = true })

  ui.split:map('n', '<cr>', function()
    local workflow_run = ui.get_workflow_run()

    if workflow_run then
      utils.open(workflow_run.html_url)

      return
    end
  end, { noremap = true })

  ui.split:map('n', 'd', function()
    local workflow = ui.get_workflow()

    if workflow then
      local repo = store.get_state().repo

      -- TODO should we get current ref instead or show an input with the
      --      default branch or current ref preselected?
      local default_branch = git.get_default_branch()

      gh.dispatch_workflow(repo, workflow.id, default_branch, {
        callback = function()
          utils.delay(2000, function()
            gh.get_workflow_runs(repo, workflow.id, 5, {
              callback = function(workflow_runs)
                store.update_state(function(state)
                  state.workflow_runs = utils.uniq(function(run)
                    return run.id
                  end, {
                    unpack(workflow_runs),
                    unpack(state.workflow_runs),
                  })
                end)
              end,
            })
          end)
        end,
      })
    end
  end, { noremap = true })

  M.timer = vim.loop.new_timer()
  M.timer:start(
    0,
    Config.options.refresh_interval * 1000,
    vim.schedule_wrap(fetch_data)
  )

  --TODO: This might get called after rendering..
  store.on_update(M.update_workflow_configs)
end

function M.close()
  ui.close()
  M.timer:stop()
  M.timer:close()
  M.timer = nil
  store.off_update(M.update_workflow_configs)
end

return M
