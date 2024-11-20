---@class TextSegment
---@field str string
---@field hl string|nil

---@alias Line TextSegment[]

---@class Buffer
---@field protected _lines Line[]
---@field protected _indent number
local Buffer = {
  ns = vim.api.nvim_create_namespace('gh-actions'),
}

---@param opts? { indent?: integer }
function Buffer.new(opts)
  local self = setmetatable({}, {
    __index = Buffer,
  })

  self:init(opts)

  return self
end

---@param opts? { indent?: integer }
function Buffer:init(opts)
  opts = opts or {}

  self._lines = {}
  self._indent = opts.indent or 2
end

---@param line Line
---@param opts? { indent?: number | nil }
function Buffer:append_line(line, opts)
  opts = opts or {}

  if opts.indent then
    table.insert(line, 1, { str = string.rep(' ', opts.indent * self._indent) })
  end

  table.insert(self._lines, line)

  return self
end

---@param str string
---@param hl? string|nil
---@param opts? { indent?: number | nil }
function Buffer:append(str, hl, opts)
  opts = opts or {}

  if #self._lines == 0 then
    table.insert(self._lines, {})
  end

  local line = str

  if opts.indent then
    line = string.rep(' ', opts.indent * self._indent) .. line
  end

  table.insert(self._lines[#self._lines], { str = line, hl = hl })

  return self
end

function Buffer:nl()
  table.insert(self._lines, {})

  return self
end

function Buffer:get_current_line_nr()
  return math.max(1, #self._lines)
end

---@param line Line
local function get_line_str(line)
  return table.concat(
    vim.tbl_map(function(segment)
      return segment.str
    end, line),
    ''
  )
end

---@param bufnr integer
function Buffer:render(bufnr)
  local lines = vim.tbl_map(get_line_str, self._lines)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(bufnr, self.ns, 0, -1)

  for l, line in ipairs(self._lines) do
    local col = 0

    for _, segment in ipairs(line) do
      local width = vim.fn.strlen(segment.str)

      ---@type string|table|nil
      local extmark = segment.hl
      if extmark then
        if type(extmark) == 'string' then
          extmark = { hl_group = extmark, end_col = col + width }
        end

        local extmark_col = extmark.col or col
        extmark.col = nil
        local line_nr = l - 1
        local ok = pcall(
          vim.api.nvim_buf_set_extmark,
          bufnr,
          self.ns,
          line_nr,
          extmark_col,
          extmark
        )
        if not ok then
          vim.notify(
            'Failed to set extmark. Please report a bug with this info:\n'
              .. vim.inspect {
                segment = segment,
                line_nr = line_nr,
                line = line,
                extmark_col = extmark_col,
                extmark = extmark,
              }
          )
        end
      end

      col = col + width
    end
  end
end

function Buffer:trim()
  while #self._lines > 0 and #self._lines[#self._lines] == 0 do
    table.remove(self._lines)
  end
end

return Buffer
