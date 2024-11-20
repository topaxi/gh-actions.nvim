function gh_utils()
  return require('gh-actions.providers.github.utils')
end

---@class pipeline.providers.github.rest.Api
local M = {}

---@param server string
---@param path string
---@param opts? table
function M.fetch(server, path, opts)
  if vim.fn.has('nvim-0.11') == 1 then
    vim.validate('server', server, 'string')
    vim.validate('path', path, 'string')
    vim.validate('opts', opts, 'table', true)
  else
    vim.validate {
      server = { server, 'string' },
      path = { path, 'string' },
      opts = { opts, 'table', true },
    }
  end

  opts = opts or {}
  opts.callback = opts.callback and vim.schedule_wrap(opts.callback)

  local url = string.format('https://api.github.com%s', path)
  if server ~= 'github.com' then
    url = string.format('https://%s/api/v3%s', server, path)
  end

  local curl = require('plenary.curl')

  return curl[opts.method or 'get'](
    url,
    vim.tbl_deep_extend('force', opts, {
      headers = {
        Authorization = string.format(
          'Bearer %s',
          gh_utils().get_github_token(nil, server)
        ),
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

---@param server string
---@param repo string
---@param opts? { callback?: fun(workflows: GhWorkflow[]): any }
function M.get_workflows(server, repo, opts)
  opts = opts or {}

  return M.fetch(
    server,
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

---@param server string
---@param repo string
---@param per_page? integer
---@param opts? { callback?: fun(workflow_runs: GhWorkflowRun[]): any }
function M.get_repository_workflow_runs(server, repo, per_page, opts)
  opts = opts or {}

  return M.fetch(
    server,
    string.format('/repos/%s/actions/runs', repo),
    vim.tbl_deep_extend('force', { query = { per_page = per_page } }, opts, {
      callback = process_workflow_runs_response(opts),
    })
  )
end

---@param server string
---@param repo string
---@param workflow_id integer|string
---@param per_page? integer
---@param opts? { callback?: fun(workflow_runs: GhWorkflowRun[]): any }
function M.get_workflow_runs(server, repo, workflow_id, per_page, opts)
  opts = opts or {}

  return M.fetch(
    server,
    string.format('/repos/%s/actions/workflows/%d/runs', repo, workflow_id),
    vim.tbl_deep_extend('force', { query = { per_page = per_page } }, opts, {
      callback = process_workflow_runs_response(opts),
    })
  )
end

---@param server string
---@param repo string
---@param workflow_id integer|string
---@param ref string
---@param opts? table
function M.dispatch_workflow(server, repo, workflow_id, ref, opts)
  opts = opts or {}

  return M.fetch(
    server,
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

---@param server string
---@param repo string
---@param workflow_run_id integer
---@param per_page? integer
---@param opts? { callback?: fun(workflow_runs: GhWorkflowRunJob[]): any }
function M.get_workflow_run_jobs(server, repo, workflow_run_id, per_page, opts)
  opts = opts or {}

  return M.fetch(
    server,
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

return M
