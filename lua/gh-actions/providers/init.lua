local providers = {
  github = 'github.rest',
}

---@class pipeline.Providers: { [string]: pipeline.Provider }
---@field github pipeline.providers.github.rest.Provider
local M = setmetatable({}, {
  __index = function(_, key)
    return require('gh-actions.providers.' .. providers[key])
  end,
})

return M
