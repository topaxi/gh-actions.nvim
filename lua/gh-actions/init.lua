local M = {
  init_root = '',
}

---@param opts? GhActionsConfig
function M.setup(opts)
  opts = opts or {}

  M.init_root = vim.fn.getcwd()

  require('gh-actions.config').setup(opts)
  require('gh-actions.ui').setup()
  require('gh-actions.command').setup()

  M.setup_provider()
end

function M.setup_provider()
  if M.pipeline then
    return
  end

  local config = require('gh-actions.config')
  local store = require('gh-actions.store')

  M.pipeline =
    require('gh-actions.providers.provider'):new(config.options, store)
  for provider, provider_options in pairs(config.options.providers) do
    local Provider = require('gh-actions.providers')[provider]

    if Provider.detect() then
      M.pipeline = Provider:new(config.options, store, provider_options)
    end
  end
end

function M.start_polling()
  M.pipeline:listen()
end

function M.stop_polling()
  M.pipeline:close()
end

local function now()
  return os.time()
end

local WORKFLOW_CONFIG_CACHE_TTL_S = 10

---TODO We should run this after fetching the workflows instead of within the state update event
---@param state GhActionsState
function M.update_workflow_configs(state)
  local gh_utils = require('gh-actions.providers.github.utils')
  local n = now()

  for _, pipeline in ipairs(state.pipelines) do
    if
      not state.workflow_configs[pipeline.pipeline_id]
      or (n - state.workflow_configs[pipeline.pipeline_id].last_read)
        > WORKFLOW_CONFIG_CACHE_TTL_S
    then
      state.workflow_configs[pipeline.pipeline_id] = {
        last_read = n,
        config = gh_utils.get_workflow_config(pipeline.meta.workflow_path),
      }
    end
  end
end

---@param pipeline_object pipeline.PipelineObject|nil
local function open_pipeline_url(pipeline_object)
  if not pipeline_object then
    return
  end

  if type(pipeline_object.url) ~= 'string' or pipeline_object.url == '' then
    return
  end

  require('gh-actions.utils').open(pipeline_object.url)
end

function M.open()
  local ui = require('gh-actions.ui')
  local store = require('gh-actions.store')

  ui.open()
  ui.split:map('n', 'q', M.close, { noremap = true })

  ui.split:map('n', { 'gp', 'gw' }, function()
    open_pipeline_url(ui.get_pipeline())
  end, { noremap = true })

  ui.split:map('n', 'gr', function()
    open_pipeline_url(ui.get_run())
  end, { noremap = true })

  ui.split:map('n', 'gj', function()
    open_pipeline_url(ui.get_job())
  end, { noremap = true })

  ui.split:map('n', 'gs', function()
    open_pipeline_url(ui.get_step())
  end, { noremap = true })

  -- TODO Move this into its own module, ui?
  ui.split:map('n', 'd', function()
    M.pipeline:dispatch(ui.get_pipeline())
  end, { noremap = true })

  M.start_polling()

  --TODO: This might get called after rendering..
  store.on_update(M.update_workflow_configs)
end

function M.close()
  local ui = require('gh-actions.ui')
  local store = require('gh-actions.store')

  ui.close()
  M.stop_polling()
  store.off_update(M.update_workflow_configs)
end

function M.toggle()
  local ui = require('gh-actions.ui')

  if ui.split.winid then
    return M.close()
  else
    return M.open()
  end
end

return M
