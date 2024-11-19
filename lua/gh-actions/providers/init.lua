local providers = {
  github = 'github.rest',
}

---@class Providers
---@field github GithubRestProvider
local M = setmetatable({}, {
  __index = function(_, key)
    return require('gh-actions.providers.' .. providers[key])
  end,
})

return M
