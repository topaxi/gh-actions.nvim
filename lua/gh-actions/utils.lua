local M = {}

---@generic T
---@param debounced_fn fun(arg1: T)
---@return fun(arg1: T)
function M.debounced(debounced_fn)
  local queued = false
  local last_arg = nil

  return function(a)
    last_arg = a

    if queued then
      return
    end

    queued = true

    vim.schedule(function()
      debounced_fn(last_arg)
      queued = false
      last_arg = nil
    end)
  end
end

---@param path string
---@return string|nil
function M.read_file(path)
  local f = io.open(path, "r")

  if not f then
    return nil
  end

  local content = f:read("*all")

  f:close()

  return content
end

return M
