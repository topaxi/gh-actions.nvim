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

---@generic T : table
---@param fn any
---@param tbl T
---@return T
function M.uniq(fn, tbl)
  local set = {}
  local unique_table = {}

  for _, v in ipairs(tbl) do
    local id = fn(v)

    if not set[id] then
      table.insert(unique_table, v)
      set[id] = true
    end
  end

  return unique_table
end

function M.delay(ms, fn)
  local timer = vim.loop.new_timer()

  if not timer then
    return
  end

  timer:start(ms, 0, function()
    timer:close()
    vim.schedule(fn)
  end)
end

---@generic T
---@param fn fun(value: T, key: number): number
---@param tbl table<number, T>
---@return table<number, T[]>
function M.group_by(fn, tbl)
  local m = {}

  for k, v in ipairs(tbl) do
    local key = fn(v, k)
    m[key] = m[key] or {}
    table.insert(m[key], v)
  end

  return m
end

return M
