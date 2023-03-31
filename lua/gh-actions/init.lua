local Split = require("nui.split")
local gh = require("gh-actions.github")

local split = Split({
  position = "right",
  size = 40,
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

  local workflows = gh.get_workflows("topaxi/learning-cs")

  print(vim.inspect(workflows))
end

function M.close()
  split:unmount()
end

return M
