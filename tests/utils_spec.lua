local utils = require('pipeline.utils')

describe('uniq', function()
  it('it remove duplicate values from table', function()
    local list = { { id = 1 }, { id = 1 }, { id = 2 }, { id = 1 }, { id = 3 } }

    local function get_id(li)
      return li.id
    end

    assert.are.same(
      utils.uniq(get_id, list),
      { { id = 1 }, { id = 2 }, { id = 3 } }
    )
  end)
end)
