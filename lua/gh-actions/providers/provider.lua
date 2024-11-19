--# selene: allow(unused_variable)

--- Generic class for all providers
---
--- We assume the following is true for most ci/cd systems:
--- 1. There's multiple different pipelines defined
---   - Github calls these Workflow
---   - Gitlab calls these Pipeline
---   - We call it Pipeline
--- 2. Each pipeline trigger an instance of a pipeline run
---   - Github calls these WorkflowRun
---   - Gitlab calls these Pipeline (they don't seem to have a different
---     terminology for the pipeline definition and a pipeline run)
---   - We call it Run
--- 3. Each pipeline has multiple jobs
---   - We all call these Job
--- 4. Each job has a name and multiple steps
---   - Github calls these Step with an optional name
---   - Gitlab has just a list of scripts
---   - We call it Step
---
--- Optionally, some providers have a concept of stages, ex. Gitlab, to group
--- jobs within a Pipeline. Groups can be used to sort/group these in the UI
--- tree.

---@class pipeline.Provider
---@field protected config GhActionsConfig
---@field protected store GhActionsStore
---@field private listener_count integer
local Provider = {}

---@return pipeline.Provider
function Provider:extend()
  return setmetatable({}, {
    __index = self,
  })
end

function Provider.detect()
  vim.notify_once('Provider does not implement detect', vim.log.levels.WARN)

  return false
end

---@generic T: pipeline.Provider
---@param config GhActionsConfig
---@param store GhActionsStore
---@param opts? table
---@return self
function Provider:new(config, store, opts)
  local instance = setmetatable({}, {
    __index = self,
  })
  instance.config = config
  instance.store = store
  instance.listener_count = 0
  instance:init(opts or {})
  return instance
end

---Constructor function, called when creating a new Provider instance.
---@param opts table
function Provider:init(opts) end

---Start fetching or listening to data from the provider.
function Provider:connect() end

---Stop fetching or listening to data from the provider.
function Provider:disconnect() end

function Provider:listen()
  if self.listener_count == 0 then
    self:connect()
  end
  self.listener_count = self.listener_count + 1
end

function Provider:close()
  self.listener_count = self.listener_count - 1
  if self.listener_count == 0 then
    self:disconnect()
  end
end

return Provider
