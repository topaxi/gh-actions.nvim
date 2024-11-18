local utils = require('gh-actions.utils')
local has_rust_module, rust = pcall(require, 'gh-actions.rust')

local M = {}

---@param path string
---@return table|nil
function M.read_yaml_file(path)
  local yamlstr = utils.read_file(path)

  return M.parse_yaml(yamlstr)
end

---@param yamlstr string|nil
---@return table|nil
function M.parse_yaml(yamlstr)
  if has_rust_module then
    return rust.parse_yaml(yamlstr or '')
  else
    local result = vim
      .system({ 'yq', '-j' }, {
        stdin = yamlstr,
        stderr = false,
      })
      :wait()
    return vim.json.decode(result.stdout)
  end
end

function M.is_yaml_nil(value)
  return has_rust_module and value == rust.NIL
end

return M
