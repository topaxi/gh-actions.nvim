---@class pipeline.Config
local defaultConfig = {
  --- The browser executable path to open workflow runs/jobs in
  ---@type string|nil
  browser = nil,
  --- How much workflow runs and jobs should be indented
  indent = 2,
  --- Provider options
  ---@class pipeline.config.Providers
  ---@field github? pipeline.providers.github.rest.Options
  ---@field gitlab? pipeline.providers.gitlab.graphql.Options
  providers = {
    github = {},
    gitlab = {},
  },
  --- Allowed hosts to fetch data from, github.com is always allowed
  --- @type string[]
  allowed_hosts = {},
  ---@class pipeline.config.Icons
  icons = {
    workflow_dispatch = '⚡️',
    ---@class pipeline.config.IconConclusion
    conclusion = {
      success = '✓',
      failure = 'X',
      startup_failure = 'X',
      cancelled = '⊘',
      skipped = '◌',
      action_required = '⚠',
    },
    ---@class pipeline.config.IconStatus
    status = {
      unknown = '?',
      pending = '○',
      queued = '○',
      requested = '○',
      waiting = '○',
      in_progress = '●',
    },
  },
  ---@class pipeline.config.Highlights
  highlights = {
    ---@type vim.api.keyset.highlight
    GhActionsRunIconSuccess = { link = 'LspDiagnosticsVirtualTextHint' },
    ---@type vim.api.keyset.highlight
    GhActionsRunIconFailure = { link = 'LspDiagnosticsVirtualTextError' },
    ---@type vim.api.keyset.highlight
    GhActionsRunIconStartup_failure = {
      link = 'LspDiagnosticsVirtualTextError',
    },
    ---@type vim.api.keyset.highlight
    GhActionsRunIconPending = { link = 'LspDiagnosticsVirtualTextWarning' },
    ---@type vim.api.keyset.highlight
    GhActionsRunIconRequested = { link = 'LspDiagnosticsVirtualTextWarning' },
    ---@type vim.api.keyset.highlight
    GhActionsRunIconWaiting = { link = 'LspDiagnosticsVirtualTextWarning' },
    ---@type vim.api.keyset.highlight
    GhActionsRunIconIn_progress = { link = 'LspDiagnosticsVirtualTextWarning' },
    ---@type vim.api.keyset.highlight
    GhActionsRunIconCancelled = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    GhActionsRunIconSkipped = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    GhActionsRunCancelled = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    GhActionsRunSkipped = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    GhActionsJobCancelled = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    GhActionsJobSkipped = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    GhActionsStepCancelled = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    GhActionsStepSkipped = { link = 'Comment' },
  },
  ---@type nui_split_options
  split = {
    relative = 'editor',
    position = 'right',
    size = 60,
    win_options = {
      wrap = false,
      number = false,
      foldlevel = nil,
      foldcolumn = '0',
      cursorcolumn = false,
      signcolumn = 'no',
    },
  },
}

local M = {
  options = defaultConfig,
}

---@param opts? pipeline.Config
function M.setup(opts)
  opts = opts or {}

  M.options = vim.tbl_deep_extend('force', defaultConfig, opts)
  M.options.allowed_hosts = M.options.allowed_hosts or {}
  table.insert(M.options.allowed_hosts, 'github.com')
end

function M.is_host_allowed(host)
  for _, allowed_host in ipairs(M.options.allowed_hosts) do
    if host == allowed_host then
      return true
    end
  end

  return false
end

return M
