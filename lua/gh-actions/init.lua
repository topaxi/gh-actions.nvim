local Split = require("nui.split")
local curl = require("plenary.curl")

---@class GhWorkflow
---@field id number
---@field node_id string
---@field name string
---@field path string
---@field state string
---@field created_at string
---@field updated_at string
---@field url string
---@field html_url string
---@field badge_url string

---@class GhWorkflowsResponse
---@field total_count number
---@field workflows GhWorkflow[]

---@param path string
local function fetch_github(path)
  return curl.get(string.format("https://api.github.com%s", path), {
    headers = {
      Authorization = string.format("Bearer %s", vim.env.GITHUB_TOKEN),
    },
  })
end

---@param repo string
local function get_github_workflows(repo)
  local response = fetch_github(string.format("/repos/%s/actions/workflows", repo))

  ---@type GhWorkflowsResponse | nil
  local responseData = vim.json.decode(response.body)

  return responseData and responseData.workflows
end

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

  local workflows = get_github_workflows("topaxi/topaxi")

  print(vim.inspect(workflows))
end

function M.close()
  split:unmount()
end

return M
