local providers = {
  gitlab = 'gitlab.graphql',
  github = 'github.rest',
}

---@class pipeline.Providers: { [string]: pipeline.Provider }
---@field github pipeline.providers.github.rest.Provider
local M = setmetatable({}, {
  __index = function(_, key)
    return require('pipeline.providers.' .. providers[key])
  end,
})

return M
