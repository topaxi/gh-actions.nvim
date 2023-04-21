local Config = require('gh-actions.config')
local Buffer = require('gh-actions.ui.buffer')
local utils = require('gh-actions.utils')

---TODO: Shade background like https://github.com/akinsho/toggleterm.nvim/blob/2e477f7ee8ee8229ff3158e3018a067797b9cd38/lua/toggleterm/colors.lua

---@class GhActionsRenderLocation
---@field value any
---@field kind string
---@field from integer
---@field to integer

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
  local self = setmetatable(Buffer.new { indent = Config.options.indent }, {
    __index = GhActionsRender,
  })
  ---@cast self GhActionsRender

  self.store = store

  return self
end

---@param bufnr integer
function GhActionsRender:render(bufnr)
  self._lines = {}
  self.locations = {}

  local state = self.store:get_state()

  self:title(state)
  self:workflows(state)
  self:trim()

  Buffer.render(self, bufnr)
end

--- Render title of the split window
---@param state GhActionsState
function GhActionsRender:title(state)
  if not state.repo then
    self:append('Github Workflows'):nl():nl()
  else
    self:append(string.format('Github Workflows for %s', state.repo)):nl():nl()
  end
end

--- Render each workflow
---@param state GhActionsState
function GhActionsRender:workflows(state)
  local workflows = state.workflows
  local workflow_runs = state.workflow_runs

  local workflow_runs_by_workflow_id = utils.group_by(function(workflow_run)
    return workflow_run.workflow_id
  end, workflow_runs)

  for _, workflow in ipairs(workflows) do
    local runs = workflow_runs_by_workflow_id[workflow.id] or {}

    self:workflow(state, workflow, runs)
  end
end

---@param state GhActionsState
---@param workflow GhWorkflow
---@param runs GhWorkflowRun[]
function GhActionsRender:workflow(state, workflow, runs)
  self:with_location({ kind = 'workflow', value = workflow }, function()
    local runs_n = math.min(5, #runs)

    self
      :fold_icon(#runs == 0)
      :status_icon(runs[1])
      :append(' ')
      :append(workflow.name, get_status_highlight(runs[1], 'run'))
      :append(
        state.workflow_configs[workflow.id]
            and state.workflow_configs[workflow.id].config.on.workflow_dispatch
            and (' ' .. Config.options.icons.workflow_dispatch)
          or ''
      )
      :nl()

    -- TODO cutting down on how many we list here, as we fetch 100 overall repo
    -- runs on opening the split. I guess we do want to have this configurable.
    for _, run in ipairs { unpack(runs, 1, runs_n) } do
      self:workflow_run(state, run)
    end
  end)

  if #runs > 0 then
    self:nl()
  end
end

---@param state GhActionsState
---@param run GhWorkflowRun
function GhActionsRender:workflow_run(state, run)
  self:with_location({ kind = 'workflow_run', value = run }, function()
    local folded = not (
        state.folds[run.id] == nil and run.status ~= 'completed'
      ) or state.folds[run.id]

    self
      :fold_icon(folded, { indent = 1 })
      :status_icon(run)
      :append(' ')
      :append(
        run.head_commit.message:gsub('\n.*', ''),
        get_status_highlight(run, 'run')
      )
      :nl()

    if folded then
      for _, job in ipairs(state.workflow_jobs[run.id] or {}) do
        self:workflow_job(state, job)
      end
    end
  end)
end

---@param state GhActionsState
---@param job GhWorkflowRunJob
function GhActionsRender:workflow_job(state, job)
  self:with_location({ kind = 'workflow_job', value = job }, function()
    local folded = not (
      state.folds[job.id] == nil and job.status ~= 'completed'
    ) or state.folds[job.id]

    self
      :fold_icon(folded, { indent = 2 })
      :status_icon(job)
      :append(' ')
      :append(job.name, get_status_highlight(job, 'job'))
      :nl()

    if folded then
      for _, step in ipairs(job.steps) do
        self:workflow_step(step)
      end
    end
  end)
end

---@param step GhWorkflowRunJobStep
function GhActionsRender:workflow_step(step)
  self:with_location({ kind = 'workflow_step', value = step }, function()
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

---@param folded boolean
---@param opts? { indent?: number | nil }
function GhActionsRender:fold_icon(folded, opts)
  self:append(folded and ' ' or ' ', nil, opts)

  return self
end

---@param location GhActionsRenderLocation
function GhActionsRender:append_location(location)
  table.insert(
    self.locations,
    vim.tbl_extend('keep', location, { to = self:get_current_line_nr() - 1 })
  )
end

---@param kind string
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
