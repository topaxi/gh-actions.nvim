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

local function dispatch_run()
  local ui = require('gh-actions.ui')
  local store = require('gh-actions.store')
  local utils = require('gh-actions.utils')
  local gh_api = require('gh-actions.providers.github.rest._api')
  local pipeline = ui.get_pipeline()

  if pipeline then
    local server = store.get_state().server
    local repo = store.get_state().repo

    -- TODO should we get current ref instead or show an input with the
    --      default branch or current ref preselected?
    local default_branch = require('gh-actions.git').get_default_branch()
    local workflow_config =
      require('gh-actions.yaml').read_yaml_file(pipeline.meta.workflow_path)

    if not workflow_config or not workflow_config.on.workflow_dispatch then
      return
    end

    local inputs = {}

    if not utils.is_nil(workflow_config.on.workflow_dispatch) then
      inputs = workflow_config.on.workflow_dispatch.inputs
    end

    local questions = {}
    local i = 0
    local input_values = vim.empty_dict()

    -- TODO: Would be great to be able to cycle back to previous inputs
    local function ask_next()
      i = i + 1

      if #questions > 0 and i <= #questions then
        questions[i]:mount()
      else
        gh_api.dispatch_workflow(
          server,
          repo,
          pipeline.pipeline_id,
          default_branch,
          {
            body = { inputs = input_values or {} },
            callback = function(_res)
              utils.delay(2000, function()
                gh_api.get_workflow_runs(
                  server,
                  repo,
                  pipeline.pipeline_id,
                  5,
                  {
                    callback = function(workflow_runs)
                      local Mapper =
                        require('gh-actions.providers.github.rest._mapper')
                      local runs = vim.tbl_map(Mapper.to_run, workflow_runs)

                      store.update_state(function(state)
                        state.runs = utils.group_by(
                          function(run)
                            return run.pipeline_id
                          end,
                          utils.uniq(function(run)
                            return run.run_id
                          end, {
                            unpack(runs),
                            unpack(vim.iter(state.runs):flatten():totable()),
                          })
                        )
                      end)
                    end,
                  }
                )
              end)
            end,
          }
        )

        if #questions == 0 then
          vim.notify(string.format('Dispatched %s', pipeline.name))
        else
          -- TODO format by iterating instead of inspect
          vim.notify(
            string.format(
              'Dispatched %s with %s',
              pipeline.name,
              vim.inspect(input_values)
            )
          )
        end
      end
    end

    for name, input in pairs(inputs) do
      local prompt = string.format('%s: ', input.description or name)

      if input.type == 'choice' then
        local question = require('gh-actions.ui.components.select') {
          prompt = prompt,
          title = pipeline.name,
          options = input.options,
          on_submit = function(value)
            input_values[name] = value.text
            ask_next()
          end,
        }

        question:on('BufLeave', function()
          question:unmount()
        end)

        table.insert(questions, question)
      else
        local question = require('gh-actions.ui.components.input') {
          prompt = prompt,
          title = pipeline.name,
          default_value = input.default,
          on_submit = function(value)
            input_values[name] = value
            ask_next()
          end,
        }

        question:on('BufLeave', function()
          question:unmount()
        end)

        table.insert(questions, question)
      end
    end

    ask_next()
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
  ui.split:map('n', 'd', dispatch_run, { noremap = true })

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
