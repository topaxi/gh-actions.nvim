local M = {}

---@param str string
---@return string
function M.upper_first(str)
  return str:sub(1, 1):upper() .. str:sub(2)
end

return M
