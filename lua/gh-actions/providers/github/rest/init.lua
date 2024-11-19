local Provider = require('gh-actions.providers.pipeline_provider')

local function is_host_allowed(host)
  local config = require('gh-actions.config')

  for _, allowed_host in ipairs(config.options.allowed_hosts) do
    if host == allowed_host then
      return true
    end
  end

  return false
end

---@class GithubRestProvider: Provider
---@field private server string
---@field private repo string
local GithubRestProvider = Provider:extend()

function GithubRestProvider.detect()
  local gh = require('gh-actions.github')
  local server, repo = gh().get_current_repository()

  if not is_host_allowed(server) then
    return
  end

  return server ~= nil and repo ~= nil
end

function GithubRestProvider:init(_opts)
  local gh = require('gh-actions.github')
  local server, repo = gh.get_current_repository()

  self.server = server
  self.repo = repo

  self.store.update_state(function(state)
    -- TODO: Repo is used in the ui title.
    state.repo = repo
  end)
end

--TODO Only periodically fetch all workflows
--     then fetch runs for a single workflow (tabs/expandable)
--     Maybe periodically fetch all workflow runs to update
--     "toplevel" workflow states
--TODO Maybe send lsp progress events when fetching, to interact
--     with fidget.nvim
function GithubRestProvider:fetch()
  local gh = require('gh-actions.github')

  gh.get_workflows(self.server, self.repo, {
    callback = function(workflows)
      self.store.update_state(function(state)
        state.workflows = workflows
      end)
    end,
  })

  gh.get_repository_workflow_runs(self.server, self.repo, 100, {
    callback = function(workflow_runs)
      local utils = require('gh-actions.utils')
      local old_workflow_runs = self.store.get_state().workflow_runs

      self.store.update_state(function(state)
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
        gh.get_workflow_run_jobs(self.server, self.repo, run.id, 20, {
          callback = function(jobs)
            self.store.update_state(function(state)
              state.workflow_jobs[run.id] = jobs
            end)
          end,
        })
      end
    end,
  })
end

function GithubRestProvider:connect()
  self.timer = vim.loop.new_timer()
  self.timer:start(
    0,
    require('gh-actions.config').options.refresh_interval * 1000,
    vim.schedule_wrap(function()
      self:fetch()
    end)
  )
end

function GithubRestProvider:disconnect()
  self.timer:stop()
  self.timer = nil
end

return GithubRestProvider
