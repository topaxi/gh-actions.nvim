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
  local gh = require('gh-actions.providers.github.rest._api')
  local n = now()

  for _, pipeline in ipairs(state.pipelines) do
    if
      not state.workflow_configs[pipeline.pipeline_id]
      or (n - state.workflow_configs[pipeline.pipeline_id].last_read)
        > WORKFLOW_CONFIG_CACHE_TTL_S
    then
      state.workflow_configs[pipeline.pipeline_id] = {
        last_read = n,
        config = gh.get_workflow_config(pipeline.meta.workflow_path),
      }
    end
  end
end

---@param opts { prompt: string, title: string, default_value: string, on_submit: fun(value: string) }
local function text(opts)
  local Input = require('nui.input')

  return Input({
    relative = 'editor',
    position = '50%',
    size = {
      width = #opts.prompt + 32,
    },
    border = {
      style = 'rounded',
      text = { top = opts.title },
    },
  }, {
    prompt = opts.prompt,
    default_value = opts.default_value,
    on_submit = opts.on_submit,
  })
end

---@param opts { prompt: string, title: string, options: string[], on_submit: fun(value: { text: string }) }
local function menu(opts)
  local Menu = require('nui.menu')
  local lines = { Menu.separator(opts.prompt) }

  for _, option in ipairs(opts.options) do
    table.insert(lines, Menu.item(option))
  end

  return Menu({
    relative = 'editor',
    position = '50%',
    size = {
      width = #opts.prompt + 32,
    },
    border = {
      style = 'rounded',
      text = { top = opts.title },
    },
  }, {
    lines = lines,
    on_submit = opts.on_submit,
    keymap = {
      focus_next = { 'j', '<Down>', '<Tab>' },
      focus_prev = { 'k', '<Up>', '<S-Tab>' },
      close = { '<Esc>', '<C-c>' },
      submit = { '<CR>', '<Space>' },
    },
  })
end

function M.open()
  local ui = require('gh-actions.ui')
  local store = require('gh-actions.store')
  local utils = require('gh-actions.utils')

  ui.open()
  ui.split:map('n', 'q', M.close, { noremap = true })

  ui.split:map('n', 'gw', function()
    local workflow = ui.get_workflow()

    if workflow then
      utils.open(workflow.html_url)

      return
    end
  end, { noremap = true })

  ui.split:map('n', 'gr', function()
    local workflow_run = ui.get_workflow_run()

    if workflow_run then
      utils.open(workflow_run.html_url)

      return
    end
  end, { noremap = true })

  ui.split:map('n', 'gj', function()
    local workflow_job = ui.get_workflow_job()

    if workflow_job then
      utils.open(workflow_job.html_url)

      return
    end
  end, { noremap = true })

  -- TODO Move this into its own module, ui?
  ui.split:map('n', 'd', function()
    local gh = require('gh-actions.providers.github.rest._api')
    local workflow = ui.get_workflow()

    if workflow then
      local server = store.get_state().server
      local repo = store.get_state().repo

      -- TODO should we get current ref instead or show an input with the
      --      default branch or current ref preselected?
      local default_branch = require('gh-actions.git').get_default_branch()
      local workflow_config =
        require('gh-actions.yaml').read_yaml_file(workflow.path)

      if not workflow_config or not workflow_config.on.workflow_dispatch then
        return
      end

      local inputs = {}

      if not utils.is_nil(workflow_config.on.workflow_dispatch) then
        inputs = workflow_config.on.workflow_dispatch.inputs
      end

      local event = require('nui.utils.autocmd').event
      local questions = {}
      local i = 0
      local input_values = vim.empty_dict()

      -- TODO: Would be great to be able to cycle back to previous inputs
      local function ask_next()
        i = i + 1

        if #questions > 0 and i <= #questions then
          questions[i]:mount()
        else
          gh.dispatch_workflow(server, repo, workflow.id, default_branch, {
            body = { inputs = input_values or {} },
            callback = function(_res)
              utils.delay(2000, function()
                gh.get_workflow_runs(server, repo, workflow.id, 5, {
                  callback = function(workflow_runs)
                    store.update_state(function(state)
                      state.runs = utils.uniq(function(run)
                        return run.id
                      end, {
                        unpack(workflow_runs),
                        unpack(state.runs),
                      })
                    end)
                  end,
                })
              end)
            end,
          })

          if #questions == 0 then
            vim.notify(string.format('Dispatched %s', workflow.name))
          else
            -- TODO format by iterating instead of inspect
            vim.notify(
              string.format(
                'Dispatched %s with %s',
                workflow.name,
                vim.inspect(input_values)
              )
            )
          end
        end
      end

      for name, input in pairs(inputs) do
        local prompt = string.format('%s: ', input.description or name)

        if input.type == 'choice' then
          local question = menu {
            prompt = prompt,
            title = workflow.name,
            options = input.options,
            on_submit = function(value)
              input_values[name] = value.text
              ask_next()
            end,
          }

          question:on(event.BufLeave, function()
            question:unmount()
          end)

          table.insert(questions, question)
        else
          local question = text {
            prompt = prompt,
            title = workflow.name,
            default_value = input.default,
            on_submit = function(value)
              input_values[name] = value
              ask_next()
            end,
          }

          question:on(event.BufLeave, function()
            question:unmount()
          end)

          table.insert(questions, question)
        end
      end

      ask_next()
    end
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
