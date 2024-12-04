local Provider = require('pipeline.providers.provider')

---@class pipeline.providers.polling.Options
---@field refresh_interval number

---@class pipeline.providers.polling.Provider: pipeline.Provider
---@field protected refresh_interval number The interval in seconds to poll for data.
local PollingProvider = Provider:extend()

---@param opts pipeline.providers.polling.Options
function PollingProvider:init(opts)
  self.refresh_interval = opts.refresh_interval
end

function PollingProvider:poll()
  vim.notify_once(
    'PollingProvider does not implement poll',
    vim.log.levels.WARN
  )
end

function PollingProvider:connect()
  self.timer = vim.loop.new_timer()
  self.timer:start(
    0,
    self.refresh_interval * 1000,
    vim.schedule_wrap(function()
      self:poll()
    end)
  )
end

function PollingProvider:disconnect()
  self.timer:stop()
  self.timer = nil
end

return PollingProvider
