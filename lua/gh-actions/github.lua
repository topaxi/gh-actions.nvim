local curl = require('plenary.curl')
local job = require('plenary.job')
local utils = require('gh-actions.utils')

---@class Github
---@field protected _host string
local Github = {}

---@param opts? { host?: string }
---@return Github
function Github.new(opts)
  opts = opts or {}

  local self = setmetatable({}, {
    __index = Github,
  })

  self._host = opts.host or 'github.com'

  return self
end

function Github:get_host()
  return self._host
end

---@param str string
---@return string
local function strip_git_suffix(str)
  if str:sub(-4) == '.git' then
    return str:sub(1, -5)
  end

  return str
end

---@return string, string
function Github.get_current_repository()
  local origin_url_job = job:new {
    command = 'git',
    args = {
      'config',
      '--get',
      'remote.origin.url',
    },
  }

  origin_url_job:sync()

  local origin_url = table.concat(origin_url_job:result(), '')

  local server, repo = strip_git_suffix(origin_url):match('([^@/:]+)[:/](.+)$')

  return repo, server
end

---@param cmd? string
---@param server? string
---@return string|nil
local function get_token_from_gh_cli(cmd, server)
  local has_gh_installed = vim.fn.executable('gh') == 1
  if not has_gh_installed and not cmd then
    return nil
  end

  local res
  if cmd then
    res = vim.fn.system(cmd)
  else
    local gh_enterprise_flag = ''
    if server ~= nil and server ~= '' then
      gh_enterprise_flag = ' --hostname ' .. vim.fn.shellescape(server)
    end
    res = vim.fn.system('gh auth token' .. gh_enterprise_flag)
  end

  local token = string.gsub(res or '', '\n', '')

  if token == '' then
    return nil
  end

  return token
end

---@param cmd? string
---@return string
function Github:get_github_token(cmd)
  return vim.env.GITHUB_TOKEN
    or get_token_from_gh_cli(cmd, self._host)
    -- TODO: We could also ask for the token here via nui
    or assert(nil, 'No GITHUB_TOKEN found in env and no gh cli config found')
end

---@param path string
---@param opts? table
function Github:fetch(path, opts)
  opts = opts or {}
  opts.callback = opts.callback and vim.schedule_wrap(opts.callback)

  local url = string.format('https://api.github.com%s', path)
  if self._host ~= 'github.com' then
    url = string.format('https://%s/api/v3%s', self._host, path)
  end

  return curl[opts.method or 'get'](
    url,
    vim.tbl_deep_extend('force', opts, {
      headers = {
        Authorization = string.format('Bearer %s', self:get_github_token()),
      },
    })
  )
end

---@class GhWorkflow
---@field id number
---@field node_id string
---@field name string
---@field path string
---@field state string
---@field created_at string
---@field updated_at string
---@field url string
---@field html_url string
---@field badge_url string

---@class GhWorkflowsResponse
---@field total_count number
---@field workflows GhWorkflow[]

---@param repo string
---@param opts? { callback?: fun(workflows: GhWorkflow[]): any }
function Github:get_workflows(repo, opts)
  opts = opts or {}

  return self:fetch(
    string.format('/repos/%s/actions/workflows', repo),
    vim.tbl_deep_extend('force', opts, {
      callback = function(response)
        if not response then
          return {}
        end

        ---@type GhWorkflowsResponse | nil
        local response_data = vim.json.decode(response.body)

        local ret = response_data and response_data.workflows or {}

        if opts.callback then
          return opts.callback(ret)
        else
          return ret
        end
      end,
    })
  )
end

---@class GhCommit
---@field id string
---@field message string

---@class GhWorkflowRun
---@field id number
---@field name string
---@field status string
---@field conclusion string
---@field workflow_id number
---@field head_commit GhCommit
---@field url string
---@field html_url string

---@class GhWorkflowRunsResponse
---@field total_count number
---@field workflow_runs GhWorkflowRun[]

---@param opts? { callback?: fun(workflow_runs: GhWorkflowRun[]): any }
local function process_workflow_runs_response(opts)
  opts = opts or {}

  ---@param response table
  ---@return GhWorkflowRunsResponse
  return function(response)
    if not response then
      return {}
    end

    ---@type GhWorkflowRunsResponse | nil
    local response_data = vim.json.decode(response.body)

    local ret = (response_data and response_data.workflow_runs or {})

    if opts.callback then
      return opts.callback(ret)
    else
      return ret
    end
  end
end

---@param repo string
---@param per_page? integer
---@param opts? { callback?: fun(workflow_runs: GhWorkflowRun[]): any }
function Github:get_repository_workflow_runs(repo, per_page, opts)
  opts = opts or {}

  return self:fetch(
    string.format('/repos/%s/actions/runs', repo),
    vim.tbl_deep_extend('force', { query = { per_page = per_page } }, opts, {
      callback = process_workflow_runs_response(opts),
    })
  )
end

---@param repo string
---@param workflow_id integer
---@param per_page? integer
---@param opts? { callback?: fun(workflow_runs: GhWorkflowRun[]): any }
function Github:get_workflow_runs(repo, workflow_id, per_page, opts)
  opts = opts or {}

  return self:fetch(
    string.format('/repos/%s/actions/workflows/%d/runs', repo, workflow_id),
    vim.tbl_deep_extend('force', { query = { per_page = per_page } }, opts, {
      callback = process_workflow_runs_response(opts),
    })
  )
end

---@param repo string
---@param workflow_id integer
---@param ref string
---@param opts? table
function Github:dispatch_workflow(repo, workflow_id, ref, opts)
  opts = opts or {}

  return self:fetch(
    string.format(
      '/repos/%s/actions/workflows/%d/dispatches',
      repo,
      workflow_id
    ),
    vim.tbl_deep_extend('force', {}, opts, {
      method = 'post',
      body = vim.json.encode(
        vim.tbl_deep_extend('force', {}, opts.body or {}, { ref = ref })
      ),
    })
  )
end

---@class GhWorkflowRunJobStep
---@field name string
---@field status string
---@field conclusion string
---@field number number

---@class GhWorkflowRunJob
---@field id number
---@field run_id number
---@field status string
---@field conclusion string
---@field name string
---@field steps GhWorkflowRunJobStep[]
---@field url string
---@field html_url string

---@class GhWorkflowRunJobsResponse
---@field total_count number
---@field jobs GhWorkflowRunJob[]

---@param repo string
---@param workflow_run_id integer
---@param per_page? integer
---@param opts? { callback?: fun(workflow_runs: GhWorkflowRunJob[]): any }
function Github:get_workflow_run_jobs(repo, workflow_run_id, per_page, opts)
  opts = opts or {}

  return self:fetch(
    string.format('/repos/%s/actions/runs/%d/jobs', repo, workflow_run_id),
    vim.tbl_deep_extend('force', { query = { per_page = per_page } }, opts, {
      callback = function(response)
        if not response then
          return {}
        end

        ---@type GhWorkflowRunJobsResponse | nil
        local response_data = vim.json.decode(response.body)

        local ret = response_data and response_data.jobs or {}

        if opts.callback then
          return opts.callback(ret)
        else
          return ret
        end
      end,
    })
  )
end

---@param path string
---@return table
function Github.get_workflow_config(path)
  path = vim.fn.expand(path)

  local workflow_yaml = utils.read_file(path) or ''
  local config = {
    on = {
      workflow_dispatch = workflow_yaml:find('workflow_dispatch'),
    },
  }

  ---@cast config table
  return config
end

return Github
