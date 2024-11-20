local Provider = require('gh-actions.providers.provider')

local function git()
  return require('gh-actions.git')
end

local function gh_api()
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
  local server, repo = git().get_current_repository()

  if not is_host_allowed(server) then
    return
  end

  return server ~= nil and repo ~= nil
end

---@param opts pipeline.providers.github.rest.Options
function GithubRestProvider:init(opts)
  local server, repo = git().get_current_repository()

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

  gh_api().get_workflows(self.server, self.repo, {
    callback = function(workflows)
      self.store.update_state(function(state)
        state.pipelines = vim.tbl_map(Mapper.to_pipeline, workflows)
      end)
    end,
  })

  gh_api().get_repository_workflow_runs(self.server, self.repo, 100, {
    callback = function(workflow_runs)
      local utils = require('gh-actions.utils')
      ---@type pipeline.Run[]
      local runs = vim.tbl_map(Mapper.to_run, workflow_runs)
      ---@type pipeline.Run[]
      local old_runs = vim.iter(self.store.get_state().runs):flatten():totable()

      self.store.update_state(function(state)
        state.latest_run = runs[1]
        state.runs = utils.group_by(function(run)
          return run.pipeline_id
        end, runs)
      end)

      local running_workflows = utils.uniq(
        function(run)
          return run.run_id
        end,
        vim.tbl_filter(function(run)
          return run.status ~= 'completed' and run.status ~= 'skipped'
        end, { unpack(runs), unpack(old_runs) })
      )

      for _, run in ipairs(running_workflows) do
        gh_api().get_workflow_run_jobs(self.server, self.repo, run.run_id, 20, {
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

function GithubRestProvider:dispatch(pipeline)
  if not pipeline then
    return
  end

  local store = require('gh-actions.store')
  local utils = require('gh-actions.utils')

  if pipeline then
    local server = store.get_state().server
    local repo = store.get_state().repo

    -- TODO should we get current ref instead or show an input with the
    --      default branch or current ref preselected?
    local default_branch = require('gh-actions.git').get_default_branch()
    local workflow_config =
      require('gh-actions.yaml').read_yaml_file(pipeline.meta.workflow_path)

    if not workflow_config or not workflow_config.on.workflow_dispatch then
      return
    end

    local inputs = {}

    if not utils.is_nil(workflow_config.on.workflow_dispatch) then
      inputs = workflow_config.on.workflow_dispatch.inputs
    end

    local questions = {}
    local i = 0
    local input_values = vim.empty_dict()

    -- TODO: Would be great to be able to cycle back to previous inputs
    local function ask_next()
      i = i + 1

      if #questions > 0 and i <= #questions then
        questions[i]:mount()
      else
        gh_api().dispatch_workflow(
          server,
          repo,
          pipeline.pipeline_id,
          default_branch,
          {
            body = { inputs = input_values or {} },
            callback = function(_res)
              utils.delay(2000, function()
                gh_api().get_workflow_runs(
                  server,
                  repo,
                  pipeline.pipeline_id,
                  5,
                  {
                    callback = function(workflow_runs)
                      local Mapper =
                        require('gh-actions.providers.github.rest._mapper')
                      local runs = vim.tbl_map(Mapper.to_run, workflow_runs)

                      store.update_state(function(state)
                        state.runs = utils.group_by(
                          function(run)
                            return run.pipeline_id
                          end,
                          utils.uniq(function(run)
                            return run.run_id
                          end, {
                            unpack(runs),
                            unpack(vim.iter(state.runs):flatten():totable()),
                          })
                        )
                      end)
                    end,
                  }
                )
              end)
            end,
          }
        )

        if #questions == 0 then
          vim.notify(string.format('Dispatched %s', pipeline.name))
        else
          -- TODO format by iterating instead of inspect
          vim.notify(
            string.format(
              'Dispatched %s with %s',
              pipeline.name,
              vim.inspect(input_values)
            )
          )
        end
      end
    end

    for name, input in pairs(inputs) do
      local prompt = string.format('%s: ', input.description or name)

      if input.type == 'choice' then
        local question = require('gh-actions.ui.components.select') {
          prompt = prompt,
          title = pipeline.name,
          options = input.options,
          on_submit = function(value)
            input_values[name] = value.text
            ask_next()
          end,
        }

        question:on('BufLeave', function()
          question:unmount()
        end)

        table.insert(questions, question)
      else
        local question = require('gh-actions.ui.components.input') {
          prompt = prompt,
          title = pipeline.name,
          default_value = input.default,
          on_submit = function(value)
            input_values[name] = value
            ask_next()
          end,
        }

        question:on('BufLeave', function()
          question:unmount()
        end)

        table.insert(questions, question)
      end
    end

    ask_next()
  end
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
