local gha = setmetatable({}, { __index = require('pipeline') })

---@override
function gha.setup(...)
  vim.notify_once(
    'topaxi/gh-actions.nvim is deprecated, use topaxi/pipeline.nvim instead',
    vim.log.levels.WARN
  )

  require('pipeline').setup(...)
end

return gha
