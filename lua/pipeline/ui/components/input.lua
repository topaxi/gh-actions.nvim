---@param opts { prompt: string, title: string, default_value: string, on_submit: fun(value: string) }
local function Input(opts)
  local NuiInput = require('nui.input')

  return NuiInput({
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

return Input
