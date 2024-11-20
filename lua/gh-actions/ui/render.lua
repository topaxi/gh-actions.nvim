local Config = require('gh-actions.config')
local Buffer = require('gh-actions.ui.buffer')
local utils = require('gh-actions.utils')

---TODO: Shade background like https://github.com/akinsho/toggleterm.nvim/blob/2e477f7ee8ee8229ff3158e3018a067797b9cd38/lua/toggleterm/colors.lua

---@alias GhActionsRenderLocationKind 'pipeline'|'run'|'job'|'step'

---@class GhActionsRenderLocation
---@field value any
---@field kind GhActionsRenderLocationKind
---@field from? integer
---@field to? integer

---@class GhActionsRender:Buffer
---@field store { get_state: fun(): GhActionsState }
---@field locations GhActionsRenderLocation[]
local GhActionsRender = {
  locations = {},
}

setmetatable(GhActionsRender, { __index = Buffer })

---@param run { status: string, conclusion: string }
---@return string
local function get_workflow_run_icon(run)
  if not run then
    return Config.options.icons.status.unknown
  end

  if run.status == 'completed' then
    return Config.options.icons.conclusion[run.conclusion] or run.conclusion
  end

  return Config.options.icons.status[run.status]
    or Config.options.icons.status.unknown
end

---@param run { status: string, conclusion: string }
---@param prefix string
---@return string|nil
local function get_status_highlight(run, prefix)
  if not run then
    return nil
  end

  if run.status == 'completed' then
    return 'GhActions'
      .. utils.string.upper_first(prefix)
      .. utils.string.upper_first(run.conclusion)
  end

  return 'GhActions'
    .. utils.string.upper_first(prefix)
    .. utils.string.upper_first(run.status)
end

---@param store { get_state: fun(): GhActionsState }
---@return GhActionsRender
function GhActionsRender.new(store)
  local self = setmetatable({}, {
    __index = GhActionsRender,
  })

  Buffer.init(self, { indent = Config.options.indent })

  self.store = store

  return self
end

---@param bufnr integer
function GhActionsRender:render(bufnr)
  self._lines = {}
  self.locations = {}

  local state = self.store:get_state()

  self:title(state)
  self:pipelines(state)
  self:trim()

  Buffer.render(self, bufnr)
end

--- Render title of the split window
---@param state GhActionsState
function GhActionsRender:title(state)
  self:append(state.title):nl():nl()
end

--- Render each pipeline
---@param state GhActionsState
function GhActionsRender:pipelines(state)
  for _, pipeline in ipairs(state.pipelines) do
    self:pipeline(state, pipeline, state.runs[pipeline.pipeline_id] or {})
  end
end

---@param state GhActionsState
---@param pipeline pipeline.Pipeline
---@param runs pipeline.Run[]
function GhActionsRender:pipeline(state, pipeline, runs)
  self:with_location({ kind = 'pipeline', value = pipeline }, function()
    local runs_n = math.min(5, #runs)

    self
      :status_icon(runs[1])
      :append(' ')
      :append(pipeline.name, get_status_highlight(runs[1], 'run'))
      :append(
        state.workflow_configs[pipeline.pipeline_id]
            and state.workflow_configs[pipeline.pipeline_id].config.on.workflow_dispatch
            and (' ' .. Config.options.icons.workflow_dispatch)
          or ''
      )
      :nl()

    -- TODO cutting down on how many we list here, as we fetch 100 overall repo
    -- runs on opening the split. I guess we do want to have this configurable.
    for _, run in ipairs { unpack(runs, 1, runs_n) } do
      self:run(state, run)
    end
  end)

  if #runs > 0 then
    self:nl()
  end
end

---@param state GhActionsState
---@param run pipeline.Run
function GhActionsRender:run(state, run)
  self:with_location({ kind = 'run', value = run }, function()
    self
      :status_icon(run, { indent = 1 })
      :append(' ')
      :append(run.name, get_status_highlight(run, 'run'))
      :nl()

    if run.status ~= 'completed' then
      for _, job in ipairs(state.jobs[run.run_id] or {}) do
        self:job(state, job)
      end
    end
  end)
end

---@param state GhActionsState
---@param job pipeline.Job
function GhActionsRender:job(state, job)
  self:with_location({ kind = 'job', value = job }, function()
    self
      :status_icon(job, { indent = 2 })
      :append(' ')
      :append(job.name, get_status_highlight(job, 'job'))
      :nl()

    if job.status ~= 'completed' and state.steps[job.job_id] then
      for _, step in ipairs(state.steps[job.job_id]) do
        self:step(step)
      end
    end
  end)
end

---@param step pipeline.Step
function GhActionsRender:step(step)
  self:with_location({ kind = 'step', value = step }, function()
    self
      :status_icon(step, { indent = 3 })
      :append(' ')
      :append(step.name, get_status_highlight(step, 'step'))
      :nl()
  end)
end

---@param status { status: string, conclusion: string }
---@param opts? { indent?: number | nil }
function GhActionsRender:status_icon(status, opts)
  opts = opts or {}

  self:append(
    get_workflow_run_icon(status),
    get_status_highlight(status, 'RunIcon'),
    opts
  )

  return self
end

---@param location GhActionsRenderLocation
function GhActionsRender:append_location(location)
  table.insert(
    self.locations,
    vim.tbl_extend('keep', location, { to = self:get_current_line_nr() - 1 })
  )
end

---@param kind GhActionsRenderLocationKind
---@param line integer
function GhActionsRender:get_location(kind, line)
  for _, loc in ipairs(self.locations) do
    if loc.kind == kind and line >= loc.from and line <= loc.to then
      return loc.value
    end
  end
end

---@param location GhActionsRenderLocation
---@param fn fun()
function GhActionsRender:with_location(location, fn)
  local start_line_nr = self:get_current_line_nr()

  fn()

  self:append_location(
    vim.tbl_extend('keep', location, { from = start_line_nr })
  )
end

return GhActionsRender
