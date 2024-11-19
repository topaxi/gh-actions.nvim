local Provider = require('gh-actions.providers.provider')

local function gh()
  return require('gh-actions.providers.github.rest._api')
end

local function is_host_allowed(host)
  local config = require('gh-actions.config')

  for _, allowed_host in ipairs(config.options.allowed_hosts) do
    if host == allowed_host then
      return true
    end
  end

  return false
end

---@class pipeline.providers.github.rest.Options
---@field refresh_interval? number
local defaultOptions = {
  refresh_interval = 10,
}

---@class pipeline.providers.github.rest.Provider: pipeline.Provider
---@field protected opts pipeline.providers.github.rest.Options
---@field private server string
---@field private repo string
local GithubRestProvider = Provider:extend()

function GithubRestProvider.detect()
  local server, repo = gh().get_current_repository()

  if not is_host_allowed(server) then
    return
  end

  return server ~= nil and repo ~= nil
end

---@param opts pipeline.providers.github.rest.Options
function GithubRestProvider:init(opts)
  local server, repo = gh().get_current_repository()

  self.opts = vim.tbl_deep_extend('force', defaultOptions, opts)
  self.server = server
  self.repo = repo

  self.store.update_state(function(state)
    state.title = string.format('Github Workflows for %s', repo)
    state.server = server
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
  local Mapper = require('gh-actions.providers.github.rest._mapper')

  gh().get_workflows(self.server, self.repo, {
    callback = function(workflows)
      self.store.update_state(function(state)
        state.pipelines = vim.tbl_map(Mapper.to_pipeline, workflows)
      end)
    end,
  })

  gh().get_repository_workflow_runs(self.server, self.repo, 100, {
    callback = function(workflow_runs)
      local utils = require('gh-actions.utils')
      local old_workflow_runs = self.store.get_state().runs

      self.store.update_state(function(state)
        state.runs = utils.group_by(function(run)
          return run.run_id
        end, vim.tbl_map(Mapper.to_run, workflow_runs))
      end)

      local running_workflows = utils.uniq(
        function(run)
          return run.run_id
        end,
        vim.tbl_filter(function(run)
          return run.status ~= 'completed' and run.status ~= 'skipped'
        end, { unpack(old_workflow_runs), unpack(workflow_runs) })
      )

      for _, run in ipairs(running_workflows) do
        gh().get_workflow_run_jobs(self.server, self.repo, run.run_id, 20, {
          callback = function(jobs)
            self.store.update_state(function(state)
              state.jobs[run.run_id] = vim.tbl_map(Mapper.to_job, jobs)

              for _, job in ipairs(jobs) do
                state.steps[job.id] = vim.tbl_map(function(step)
                  return Mapper.to_step(job.id, step)
                end, job.steps)
              end
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
    self.opts.refresh_interval * 1000,
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
