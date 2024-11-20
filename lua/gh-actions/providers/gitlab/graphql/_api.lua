local utils = require('gh-actions.utils')
local M = {}
local query_cache = {}

local function is_win()
  return package.config:sub(1, 1) == '\\'
end

local function get_path_separator()
  if is_win() then
    return '\\'
  end
  return '/'
end

--- There has to be a better way, no?
local function script_path()
  local str = debug.getinfo(2, 'S').source:sub(2)
  if is_win() then
    str = str:gsub('/', '\\')
  end
  return str:match('(.*' .. get_path_separator() .. ')')
end

function get_query(query_name)
  if not query_cache[query_name] then
    local current_dirname = script_path()
    query_cache[query_name] = utils.read_file(
      current_dirname
        .. 'queries'
        .. get_path_separator()
        .. query_name
        .. '.graphql'
    )
  end

  return query_cache[query_name]
end

---@param job Job
local function create_job(job)
  return require('plenary.job'):new(job)
end

local function glab_graphql(query, variables)
  local args = {
    'api',
    'graphql',
    '-f',
    'query=' .. query,
  }

  for key, value in pairs(variables) do
    table.insert(args, '-F')
    table.insert(args, key .. '=' .. value)
  end

  return create_job {
    command = 'glab',
    args = args,
  }
end

---@alias pipeline.providers.gitlab.graphql.CiJobStatus 'CANCELED'|'CANCELING'|'CREATED'|'FAILED'|'MANUAL'|'PENDING'|'PREPARING'|'RUNNING'|'SCHEDULED'|'SKIPPED'|'SUCCESS'|'WAITING_FOR_CALLBACK'|'WAITING_FOR_RESOURCE'
---@alias pipeline.providers.gitlab.graphql.PipelineStatus 'CREATED'|'WAITING_FOR_RESOURCE'|'PREPARING'|'WAITING_FOR_CALLBACK'|'PENDING'|'RUNNING'|'FAILED'|'SUCCESS'|'CANCELED'|'CANCELING'|'SKIPPED'|'MANUAL'|'SCHEDULED'

---@class pipeline.providers.gitlab.graphql.QueryResponseJob
---@field id string
---@field name string
---@field status pipeline.providers.gitlab.graphql.CiJobStatus
---@field manualJob boolean
---@field retryable boolean
---@field cancelable boolean
---@field stage { name: string }
---@field webPath string

---@class pipeline.providers.gitlab.graphql.QueryResponsePipeline
---@field id string
---@field name string|nil
---@field commit { message: string }
---@field path string
---@field cancelable boolean
---@field retryable boolean
---@field createdAt string
---@field status pipeline.providers.gitlab.graphql.PipelineStatus
---@field jobs { nodes: pipeline.providers.gitlab.graphql.QueryResponseJob[] }

---@class pipeline.providers.gitlab.graphql.QueryResponseProject
---@field id string
---@field ciConfigPathOrDefault string
---@field pipelines { nodes: pipeline.providers.gitlab.graphql.QueryResponsePipeline[] }

---@class pipeline.providers.gitlab.graphql.QueryResponse
---@field data { project: pipeline.providers.gitlab.graphql.QueryResponseProject }

---@param repo string
---@param limit number
---@param callback fun(response: pipeline.providers.gitlab.graphql.QueryResponse)
function M.get_project_pipelines(repo, limit, callback)
  local query = get_query('pipelines_with_jobs')
  local query_job = glab_graphql(query, { repo = repo, limit = limit })

  query_job:start()
  query_job:after(function(job)
    callback(vim.json.decode(table.concat(job:result(), '')))
  end)
end

return M
