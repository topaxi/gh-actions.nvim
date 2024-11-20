local Provider = require('gh-actions.providers.provider')

local function git()
  return require('gh-actions.git')
end

function glab_api()
  return require('gh-actions.providers.gitlab.graphql._api')
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

---@class pipeline.providers.gitlab.graphql.Options
---@field refresh_interval? number
local defaultOptions = {
  refresh_interval = 10,
}

---@class pipeline.providers.gitlab.graphql.Provider: pipeline.Provider
---@field protected opts pipeline.providers.gitlab.graphql.Options
---@field private server string
---@field private repo string
local GitlabGraphQLProvider = Provider:extend()

function GitlabGraphQLProvider.detect()
  local server, repo = git().get_current_repository()

  if not is_host_allowed(server) then
    return
  end

  return server ~= nil and repo ~= nil
end

---@param opts pipeline.providers.github.rest.Options
function GitlabGraphQLProvider:init(opts)
  local server, repo = git().get_current_repository()

  self.opts = vim.tbl_deep_extend('force', defaultOptions, opts)
  self.server = server
  self.repo = repo

  self.store.update_state(function(state)
    state.title = string.format('Gitlab Pipelines for %s', repo)
    state.server = server
    state.repo = repo
  end)
end

function GitlabGraphQLProvider:fetch()
  local utils = require('gh-actions.utils')
  local Mapper = require('gh-actions.providers.gitlab.graphql._mapper')

  glab_api().get_project_pipelines(self.repo, 10, function(response)
    if
      utils.is_nil(response.data) or type(response.data.project) == 'userdata'
    then
      -- TODO: Handle errors
      return
    end

    local pipeline = Mapper.to_pipeline(response.data.project)
    local runs = {
      [pipeline.pipeline_id] = vim.tbl_map(function(node)
        return Mapper.to_run(pipeline.id, node)
      end, response.data.project.pipelines.nodes),
    }
    local jobs = utils.group_by(
      function(job)
        return job.run_id
      end,
      vim
        .iter(response.data.project.pipelines.nodes)
        :map(function(node)
          return vim.tbl_map(function(job)
            return Mapper.to_job(node.id, job)
          end, node.jobs.nodes)
        end)
        :flatten()
        :totable()
    )

    self.store.update_state(function(state)
      state.pipelines = { pipeline }
      state.runs = runs
      state.jobs = jobs
    end)
  end)
end

---@param pipeline pipeline.providers.gitlab.graphql.Pipeline|nil
function GitlabGraphQLProvider:dispatch(pipeline)
  if not pipeline then
    return
  end

  local store = require('gh-actions.store')
  local utils = require('gh-actions.utils')

  if pipeline then
    local server = store.get_state().server
    local repo = store.get_state().repo

    local default_branch = require('gh-actions.git').get_default_branch()
    local ci_config =
      require('gh-actions.yaml').read_yaml_file(pipeline.meta.ci_config_path)

    -- TODO
  end
end

function GitlabGraphQLProvider:connect()
  self.timer = vim.loop.new_timer()
  self.timer:start(
    0,
    self.opts.refresh_interval * 1000,
    vim.schedule_wrap(function()
      self:fetch()
    end)
  )
end

function GitlabGraphQLProvider:disconnect()
  self.timer:stop()
  self.timer = nil
end

return GitlabGraphQLProvider
