---@param opts { prompt: string, title: string, options: string[], on_submit: fun(value: { text: string }) }
local function Select(opts)
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

return Select
