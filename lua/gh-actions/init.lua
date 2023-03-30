local event = require("nui.utils.autocmd").event
local Split = require("nui.split")

local split = Split({
  position = "right",
  size = 40,
  border = {
    text = {
      top = "Github Workflows",
    },
  },
})

local M = {
  setup_called = false,
  init_root = "",
}

function M.setup()
  M.init_root = vim.fn.getcwd()

  M.setup_called = true
end

function M.open()
  split:mount()
end

function M.close()
  split:unmount()
end

return M
