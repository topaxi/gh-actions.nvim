---@class pipeline.providers.github.Utils
local M = {}

---@param cmd? string
---@param server? string
---@return string|nil
local function get_token_from_gh_cli(cmd, server)
  local has_gh_installed = vim.fn.executable('gh') == 1
  if not has_gh_installed and not cmd then
    return nil
  end

  local res
  if cmd then
    res = vim.fn.system(cmd)
  else
    local gh_enterprise_flag = ''
    if server ~= nil and server ~= '' then
      gh_enterprise_flag = ' --hostname ' .. vim.fn.shellescape(server)
    end
    res = vim.fn.system('gh auth token' .. gh_enterprise_flag)
  end

  local token = string.gsub(res or '', '\n', '')

  if token == '' then
    return nil
  end

  return token
end

---@param cmd? string
---@param server? string
---@return string, string
function M.get_github_token(cmd, server)
  local token = vim.env.GITHUB_TOKEN

  if token then
    return token, 'env'
  end

  token = get_token_from_gh_cli(cmd, server)

  if token then
    return token, 'gh'
  end

  -- TODO: We could also ask for the token here via nui and store it ourselves
  assert(nil, 'No GITHUB_TOKEN found in env and no gh cli config found')
end

---@param path string
---@return table
function M.get_workflow_config(path)
  path = vim.fn.expand(path)

  local utils = require('pipeline.utils')
  local workflow_yaml = utils.read_file(path) or ''
  local config = {
    on = {
      workflow_dispatch = workflow_yaml:find('workflow_dispatch'),
    },
  }

  ---@cast config table
  return config
end

return M
