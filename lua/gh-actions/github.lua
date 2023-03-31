local curl = require("plenary.curl")
local job = require("plenary.job")

local M = {}

---TODO instead of invoking git, we could parse the remote ourselves
---@param repository_dir? string
function M.get_current_repository(repository_dir)
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

---@return string
local function read_gh_hosts_token()
  -- TODO: Can we not depend on `yq` for parsing yml?
  local yq = job:new({
    command = "yq",
    args = { "-o", "json", vim.fn.expand("$HOME/.config/gh/hosts.yml") },
  })

  yq:sync()

  local jsonStr = table.concat(yq:result(), "\n")
  local ghHostsConfig = vim.json.decode(jsonStr)

  return ghHostsConfig["github.com"].oauth_token
end

---@return string
local function get_github_token()
  return vim.env.GITHUB_TOKEN
    or read_gh_hosts_token()
    -- TODO: We could also ask for the token here via nui
    or assert(nil, "No GITHUB_TOKEN found in env and no gh cli config found")
end

---@param path string
---@param opts? table
function M.fetch(path, opts)
  opts = opts or {}

  return curl.get(
    string.format("https://api.github.com%s", path),
    vim.tbl_deep_extend("force", opts, {
      headers = {
        Authorization = string.format("Bearer %s", get_github_token()),
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

---@param repo string
---@param per_page? integer
---@param opts? table
function M.get_workflow_runs(repo, per_page, opts)
  opts = opts or {}

  return M.fetch(
    string.format("/repos/%s/actions/runs", repo),
    vim.tbl_deep_extend("force", { query = { per_page = per_page } }, opts, {
      callback = function(response)
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
      end,
    })
  )
end

return M
