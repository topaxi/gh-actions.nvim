local curl = require("plenary.curl")
local job = require("plenary.job")
local yaml = require("gh-actions-vendor.yaml")
local utils = require("gh-actions.utils")

local M = {}

function M.get_current_repository()
  -- 1. get git dir
  -- 2. get current branch
  -- 3. get origin of branch
  -- 4. parse github owner/repo from origin
  local gh = job:new({
    command = "gh",
    args = { "repo", "view", "--json", "owner,name", "--template", "{{.owner.login}}/{{.name}}" },
  })

  gh:sync()

  return table.concat(gh:result(), "")
end

---@param config_file? string
---@return string|nil
local function read_gh_hosts_token(config_file)
  config_file = vim.fn.expand(config_file or "$HOME/.config/gh/hosts.yml")

  local ghHostsYaml = utils.read_file(config_file) or ""
  local ghHostsConfig = yaml.eval(ghHostsYaml)
  local token = ghHostsConfig and ghHostsConfig["github.com"].oauth_token

  return token
end

---@param config_file? string
---@return string
function M.get_github_token(config_file)
  return vim.env.GITHUB_TOKEN
    or read_gh_hosts_token(config_file)
    -- TODO: We could also ask for the token here via nui
    or assert(nil, "No GITHUB_TOKEN found in env and no gh cli config found")
end

---@param path string
---@param opts? table
function M.fetch(path, opts)
  opts = opts or {}
  opts.callback = opts.callback and vim.schedule_wrap(opts.callback)

  return curl[opts.method or "get"](
    string.format("https://api.github.com%s", path),
    vim.tbl_deep_extend("force", opts, {
      headers = {
        Authorization = string.format("Bearer %s", M.get_github_token()),
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
---@param opts? table
function M.get_workflows(repo, opts)
  opts = opts or {}

  return M.fetch(
    string.format("/repos/%s/actions/workflows", repo),
    vim.tbl_deep_extend("force", opts, {
      callback = function(response)
        if not response then
          return {}
        end

        ---@type GhWorkflowsResponse | nil
        local responseData = vim.json.decode(response.body)

        local ret = responseData and responseData.workflows or {}

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

---@class GhWorkflowRunsResponse
---@field total_count number
---@field workflow_runs GhWorkflowRun[]

---@param opts? table
local function process_workflow_runs_response(opts)
  opts = opts or {}

  ---@param response table
  ---@return GhWorkflowRunsResponse
  return function(response)
    if not response then
      return {}
    end

    ---@type GhWorkflowRunsResponse | nil
    local responseData = vim.json.decode(response.body)

    local ret = (responseData and responseData.workflow_runs or {})

    if opts.callback then
      return opts.callback(ret)
    else
      return ret
    end
  end
end

---@param repo string
---@param per_page? integer
---@param opts? table
function M.get_repository_workflow_runs(repo, per_page, opts)
  opts = opts or {}

  return M.fetch(
    string.format("/repos/%s/actions/runs", repo),
    vim.tbl_deep_extend("force", { query = { per_page = per_page } }, opts, {
      callback = process_workflow_runs_response(opts),
    })
  )
end

---@param repo string
---@param workflow_id integer
---@param per_page? integer
---@param opts? table
function M.get_workflow_runs(repo, workflow_id, per_page, opts)
  opts = opts or {}

  return M.fetch(
    string.format("/repos/%s/actions/workflows/%d/runs", repo, workflow_id),
    vim.tbl_deep_extend("force", { query = { per_page = per_page } }, opts, {
      callback = process_workflow_runs_response(opts),
    })
  )
end

---@param repo string
---@param workflow_id integer
---@param ref string
---@param opts? table
function M.dispatch_workflow(repo, workflow_id, ref, opts)
  opts = opts or {}

  return M.fetch(
    string.format("/repos/%s/actions/workflows/%d/dispatches", repo, workflow_id),
    vim.tbl_deep_extend("force", {}, opts, {
      method = "post",
      body = vim.json.encode(vim.tbl_deep_extend("force", {}, opts.body or {}, { ref = ref })),
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

---@class GhWorkflowRunJobsResponse
---@field total_count number
---@field jobs GhWorkflowRunJob[]

---@param repo string
---@param workflow_run_id integer
---@param per_page? integer
---@param opts? table
function M.get_workflow_run_jobs(repo, workflow_run_id, per_page, opts)
  opts = opts or {}

  return M.fetch(
    string.format("/repos/%s/actions/runs/%d/runs", repo, workflow_run_id),
    vim.tbl_deep_extend("force", { query = { per_page = per_page } }, opts, {
      callback = function(response)
        if not response then
          return {}
        end

        ---@type GhWorkflowRunJobsResponse | nil
        local responseData = vim.json.decode(response.body)

        local ret = responseData and responseData.jobs or {}

        if opts.callback then
          return opts.callback(ret)
        else
          return ret
        end
      end,
    })
  )
end

---TODO lua-yaml is not able to fully parse most yaml files..
---@param path string
---@return table
function M.get_workflow_config(path)
  path = vim.fn.expand(path)

  local workflow_yaml = utils.read_file(path) or ""
  local config = {
    on = {
      workflow_dispatch = workflow_yaml:find("workflow_dispatch"),
    },
  }

  ---@cast config table
  return config
end

return M
