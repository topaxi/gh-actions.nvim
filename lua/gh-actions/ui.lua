local Split = require("nui.split")
local store = require("gh-actions.store")
local utils = require("gh-actions.utils")
local Buffer = require("gh-actions.ui.buffer")

local split = Split({
  relative = "editor",
  position = "right",
  size = 60,
  win_options = {
    wrap = false,
    number = false,
    foldlevel = nil,
    foldcolumn = "0",
    cursorcolumn = false,
    signcolumn = "no",
  },
})

---@class GhActionsRenderLocation
---@field value any
---@field kind string
---@field from integer
---@field to integer

local M = {
  split = split,
  ---@type GhActionsRenderLocation[]
  locations = {},
  -- TODO: Maybe switch to codicons via nerdfont
  --       https://microsoft.github.io/vscode-codicons/dist/codicon.html
  --       https://www.nerdfonts.com/cheat-sheet
  icons = {
    conclusion = {
      success = "✓",
      failure = "X",
      startup_failure = "X",
      cancelled = "⊘",
      skipped = "◌",
    },
    status = {
      unknown = "?",
      pending = "○",
      queued = "○",
      requested = "○",
      waiting = "○",
      in_progress = "●",
    },
  },
  highlights = {
    GhActionsRunIconSuccess = { link = "LspDiagnosticsVirtualTextHint" },
    GhActionsRunIconFailure = { link = "LspDiagnosticsVirtualTextError" },
    GhActionsRunIconStartup_failure = { link = "LspDiagnosticsVirtualTextError" },
    GhActionsRunIconPending = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconRequested = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconWaiting = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconIn_progress = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconCancelled = { link = "Comment" },
    GhActionsRunIconSkipped = { link = "Comment" },
    GhActionsRunCancelled = { link = "Comment" },
    GhActionsRunSkipped = { link = "Comment" },
    GhActionsJobCancelled = { link = "Comment" },
    GhActionsJobSkipped = { link = "Comment" },
    GhActionsStepCancelled = { link = "Comment" },
    GhActionsStepSkipped = { link = "Comment" },
  },
}

---@param run { status: string, conclusion: string }
---@return string
local function get_workflow_run_icon(run)
  if not run then
    return M.icons.status.unknown
  end

  if run.status == "completed" then
    return M.icons.conclusion[run.conclusion] or run.conclusion
  end

  return M.icons.status[run.status] or M.icons.status.unknown
end

---@param buf Buffer
---@param state GhActionsState
local function renderTitle(buf, state)
  if not state.repo then
    buf:append("Github Workflows"):nl()
  end

  buf:append(string.format("Github Workflows for %s", state.repo)):nl()
end

local function get_cursor_line(line)
  return line or vim.api.nvim_win_get_cursor(split.winid)[1]
end

---TODO: This should be a local function
---@param line? integer
---@return GhWorkflow|nil
function M.get_workflow(line)
  line = get_cursor_line(line)

  for _, loc in ipairs(M.locations) do
    if loc.kind == "workflow" and line >= loc.from and line <= loc.to then
      return loc.value
    end
  end
end

---TODO: This should be a local function
---@param line? integer
---@return GhWorkflowRun|nil
function M.get_workflow_run(line)
  line = get_cursor_line(line)

  for _, loc in ipairs(M.locations) do
    if loc.kind == "workflow_run" and line >= loc.from and line <= loc.to then
      return loc.value
    end
  end
end

---@param str string
---@return string
local function upper_first(str)
  return str:sub(1, 1):upper() .. str:sub(2)
end

---@param run { status: string, conclusion: string }
---@param prefix string
---@return string|nil
local function get_status_highlight(run, prefix)
  if not run then
    return nil
  end

  if run.status == "completed" then
    return "GhActions" .. upper_first(prefix) .. upper_first(run.conclusion)
  end

  return "GhActions" .. upper_first(prefix) .. upper_first(run.status)
end

---@param run { status: string, conclusion: string }
---@return TextSegment
local function renderWorkflowRunIcon(run)
  return { str = get_workflow_run_icon(run), hl = get_status_highlight(run, "RunIcon") }
end

---@param location GhActionsRenderLocation
local function append_location(location)
  table.insert(M.locations, location)
end

---@param buf Buffer
---@param state GhActionsState
local function renderWorkflows(buf, state)
  local workflows = state.workflows
  local workflow_runs = state.workflow_runs

  local workflow_runs_by_workflow_id = utils.group_by(function(workflow_run)
    return workflow_run.workflow_id
  end, workflow_runs)

  for _, workflow in ipairs(workflows) do
    local runs = workflow_runs_by_workflow_id[workflow.id] or {}
    local runs_n = math.min(5, #runs)

    buf:append_line({
      renderWorkflowRunIcon(runs[1]),
      { str = " " },
      { str = workflow.name, hl = get_status_highlight(runs[1], "run") },
      {
        str = state.workflow_configs[workflow.id]
            and state.workflow_configs[workflow.id].config.on.workflow_dispatch
            and " ⚡️"
          or "",
      },
    })

    append_location({
      kind = "workflow",
      value = workflow,
      from = buf:get_current_line(),
      to = buf:get_current_line() + runs_n,
    })

    -- TODO cutting down on how many we list here, as we fetch 100 overall repo
    -- runs on opening the split. I guess we do want to have this configurable.
    for _, run in ipairs({ unpack(runs, 1, runs_n) }) do
      buf:append_line({
        renderWorkflowRunIcon(run),
        { str = " " },
        { str = run.head_commit.message:gsub("\n.*", ""), hl = get_status_highlight(run, "run") },
      }, { indent = 2 })

      local runline = buf:get_current_line()

      if run.conclusion ~= "success" then
        for _, job in ipairs(state.workflow_jobs[run.id] or {}) do
          buf:append_line({
            renderWorkflowRunIcon(job),
            { str = " " },
            { str = job.name, hl = get_status_highlight(job, "job") },
          }, { indent = 4 })

          local jobline = buf:get_current_line()

          if job.conclusion ~= "success" then
            for _, step in ipairs(job.steps) do
              buf:append_line({
                renderWorkflowRunIcon(step),
                { str = " " },
                { str = step.name, hl = get_status_highlight(step, "step") },
              }, { indent = 6 })

              append_location({
                kind = "workflow_step",
                value = job,
                from = buf:get_current_line(),
                to = buf:get_current_line(),
              })
            end
          end

          append_location({
            kind = "workflow_job",
            value = job,
            from = jobline,
            to = buf:get_current_line(),
          })
        end
      end

      append_location({
        kind = "workflow_run",
        value = run,
        from = runline,
        to = buf:get_current_line(),
      })
    end

    if #runs > 0 then
      buf:nl()
    end
  end
end

local function is_visible()
  return split.bufnr ~= nil and vim.bo[split.bufnr] ~= nil
end

---@param state GhActionsState
function M.render(state)
  M.locations = {}

  if not is_visible() then
    return
  end

  vim.bo[split.bufnr].modifiable = true

  local buf = Buffer.new()

  renderTitle(buf, state)
  renderWorkflows(buf, state)

  buf:render(split.bufnr)

  vim.bo[split.bufnr].modifiable = false
end

---@class GhActionsRenderOptions
---TODO: https://github.com/akinsho/toggleterm.nvim/blob/2e477f7ee8ee8229ff3158e3018a067797b9cd38/lua/toggleterm/colors.lua
---@field shade_background boolean
---@field icons? { conclusion?: table, status?: table }

---@param render_options? GhActionsRenderOptions
function M.setup(render_options)
  render_options = render_options or {}

  M.icons = vim.tbl_deep_extend("force", {}, M.icons, render_options.icons or {})

  for hl_group, hl_group_value in pairs(M.highlights) do
    vim.api.nvim_set_hl(0, hl_group, hl_group_value)
  end
end

function M.open()
  split:mount()

  store.on_update(M.render)
  M.render(store.get_state())
end

function M.close()
  split:unmount()
  store.off_update(M.render)
end

return M
