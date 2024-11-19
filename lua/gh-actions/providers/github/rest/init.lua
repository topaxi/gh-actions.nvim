local gh = require('gh-actions.github')
local Provider = require('gh-actions.providers.pipeline_provider')

---@class GithubRestProvider: Provider
---@field private server string
---@field private repo string
local GithubRestProvider = Provider:extend()

function GithubRestProvider:init(_opts)
  local server, repo = gh.get_current_repository()

  self.server = server
  self.repo = repo

  self.store.update_state(function(state)
    -- TODO: Repo is used in the ui title.
    state.repo = repo
  end)
end

function GithubRestProvider:fetch() end

function GithubRestProvider:connect()
  self.timer = vim.loop.new_timer()
  self.timer:start(
    0,
    require('gh-actions.config').options.refresh_interval * 1000,
    vim.schedule_wrap(function()
      self.fetch()
    end)
  )
end

function GithubRestProvider:disconnect()
  self.timer:stop()
  self.timer = nil
end

return GithubRestProvider
