local Split = require("nui.split")
local store = require("gh-actions.store")
local utils = require("gh-actions.utils")

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
  ns = vim.api.nvim_create_namespace("gh-actions"),
  split = split,
  -- TODO: While rendering, store row/line (start line,end line) and kind
  ---@type GhActionsRenderLocation[]
  locations = {},
  -- TODO: Maybe switch to codicons via nerdfont
  --       https://microsoft.github.io/vscode-codicons/dist/codicon.html
  --       https://www.nerdfonts.com/cheat-sheet
  icons = {
    conclusion = {
      success = "✓",
      failure = "X",
      cancelled = "⊘",
    },
    status = {
      unknown = "?",
      pending = "●",
      queued = "●",
      requested = "●",
      waiting = "●",
      in_progress = "●",
    },
  },
  highlights = {
    GhActionsRunIconSuccess = { link = "LspDiagnosticsVirtualTextHint" },
    GhActionsRunIconFailure = { link = "LspDiagnosticsVirtualTextError" },
    GhActionsRunIconPending = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconRequested = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconWaiting = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconIn_progress = { link = "LspDiagnosticsVirtualTextWarning" },
    GhActionsRunIconCancelled = { link = "Comment" },
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

---@param state GhActionsState
local function renderTitle(state)
  if not state.repo then
    return { "Github Workflows", "" }
  end

  return { string.format("Github Workflows for %s", state.repo), "" }
end

local function get_current_line(line)
  return line or vim.api.nvim_win_get_cursor(split.winid)[1]
end

---TODO: This should be a local function
---@param line? integer
---@return GhWorkflow|nil
function M.get_workflow(line)
  line = get_current_line(line)

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
  line = get_current_line(line)

  for _, loc in ipairs(M.locations) do
    if loc.kind == "workflow_run" and line >= loc.from and line <= loc.to then
      return loc.value
    end
  end
end

---@class TextSegment
---@field str string
---@field hl string

---@alias Line TextSegment[]

---@param line Line
local function get_line_str(line)
  return table.concat(
    vim.tbl_map(function(segment)
      return segment.str
    end, line),
    ""
  )
end

---@param str string
---@return string
local function upper_first(str)
  return str:sub(1, 1):upper() .. str:sub(2)
end

---@param run { status: string, conclusion: string }
---@return string|nil
local function get_workflow_run_icon_highlight(run)
  if not run then
    return nil
  end

  if run.status == "completed" then
    return "GhActionsRunIcon" .. upper_first(run.conclusion)
  end

  return "GhActionsRunIcon" .. upper_first(run.status)
end

---@param run { status: string, conclusion: string }
---@return TextSegment
local function renderWorkflowRunIcon(run)
  return { str = get_workflow_run_icon(run), hl = get_workflow_run_icon_highlight(run) }
end

---@param location GhActionsRenderLocation
local function append_location(location)
  table.insert(M.locations, location)
end

---@param state GhActionsState
---@return table
local function renderWorkflows(state)
  local workflows = state.workflows
  local workflow_runs = state.workflow_runs

  ---@type Line[]
  local lines = {}
  local workflow_runs_by_workflow_id = utils.group_by(function(workflow_run)
    return workflow_run.workflow_id
  end, workflow_runs)
  local currentline = 2

  for _, workflow in ipairs(workflows) do
    currentline = currentline + 1
    local runs = workflow_runs_by_workflow_id[workflow.id] or {}
    local runs_n = math.min(5, #runs)

    append_location({
      kind = "workflow",
      value = workflow,
      from = currentline,
      to = currentline + runs_n,
    })

    -- TODO Render ⚡️ or ✨ if workflow has workflow dispatch
    table.insert(lines, {
      renderWorkflowRunIcon(runs[1]),
      { str = " " },
      { str = workflow.name },
      {
        str = state.workflow_configs[workflow.id]
            and state.workflow_configs[workflow.id].config.on.workflow_dispatch
            and " ⚡️"
          or "",
      },
    })

    -- TODO cutting down on how many we list here, as we fetch 100 overall repo
    -- runs on opening the split. I guess we do want to have this configurable.
    for _, run in ipairs({ unpack(runs, 1, runs_n) }) do
      currentline = currentline + 1

      local runline = currentline

      table.insert(lines, {
        { str = "  " },
        renderWorkflowRunIcon(run),
        { str = " " },
        { str = run.head_commit.message:gsub("\n.*", "") },
      })

      if run.conclusion ~= "success" then
        for _, job in ipairs(state.workflow_jobs[run.id] or {}) do
          currentline = currentline + 1
          local jobline = currentline

          table.insert(lines, {
            { str = "    " },
            renderWorkflowRunIcon(job),
            { str = " " },
            { str = job.name },
          })

          for _, step in ipairs(job.steps) do
            currentline = currentline + 1

            append_location({
              kind = "workflow_step",
              value = job,
              from = currentline,
              to = currentline,
            })

            table.insert(lines, {
              { str = "      " },
              renderWorkflowRunIcon(step),
              { str = " " },
              { str = step.name },
            })
          end

          append_location({
            kind = "workflow_job",
            value = job,
            from = currentline,
            to = jobline,
          })
        end
      end

      append_location({
        kind = "workflow_run",
        value = run,
        from = runline,
        to = currentline,
      })
    end

    if #runs > 0 then
      currentline = currentline + 1
      table.insert(lines, { { str = "" } })
    end
  end

  return lines
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

  local workflowLines = renderWorkflows(state)

  local lines = vim.tbl_flatten({
    renderTitle(state),
    vim.tbl_map(get_line_str, workflowLines),
  })

  vim.api.nvim_buf_set_lines(split.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(split.bufnr, M.ns, 0, -1)

  for l, line in ipairs(workflowLines) do
    local col = 0

    for _, segment in ipairs(line) do
      local width = vim.fn.strlen(segment.str)

      local extmark = segment.hl
      if extmark then
        if type(extmark) == "string" then
          extmark = { hl_group = extmark, end_col = col + width }
        end

        local extmark_col = extmark.col or col
        extmark.col = nil
        ---TODO: Remove "+ 2" once we refactor title and workflow rendering into one "flow"
        local line_nr = l - 1 + 2
        local ok = pcall(vim.api.nvim_buf_set_extmark, split.bufnr, M.ns, line_nr, extmark_col, extmark)
        if not ok then
          vim.notify("Failed to set extmark. Please report a bug with this info:\n" .. vim.inspect({
            segment = segment,
            line_nr = line_nr,
            line = line,
            extmark_col = extmark_col,
            extmark = extmark,
          }))
        end
      end

      col = col + width
    end
  end

  vim.bo[split.bufnr].modifiable = false
end

---@class GhActionsRenderOptions
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
