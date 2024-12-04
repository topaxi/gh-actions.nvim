local providers = {
  gitlab = 'gitlab.graphql',
  github = 'github.rest',
}

---@class pipeline.Providers: { [string]: pipeline.Provider }
---@field github pipeline.providers.github.rest.Provider
local M = setmetatable({}, {
  __index = function(self, key)
    local Provider = require('pipeline.providers.' .. providers[key])
    self[key] = Provider
    return Provider
  end,
})

return M
