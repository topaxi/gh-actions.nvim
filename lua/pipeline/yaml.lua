local utils = require('pipeline.utils')
local has_native_module, native_yaml = pcall(require, 'pipeline_native.yaml')

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
  if has_native_module then
    return native_yaml.parse_yaml(yamlstr or '')
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
  return has_native_module and value == native_yaml.NIL
end

return M
