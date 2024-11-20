describe('get_github_token', function()
  local gh = require('pipeline.providers.github.utils')

  before_each(function()
    vim.env.GITHUB_TOKEN = nil
  end)

  it('should read from gh/hosts.yml', function()
    local token = gh.get_github_token('echo topaxitesttoken')

    assert.are.same('topaxitesttoken', token)
  end)

  it('should read from GITHUB_TOKEN', function()
    vim.env.GITHUB_TOKEN = 'envtoken'

    local token = gh.get_github_token('echo topaxitesttoken')

    assert.are.same('envtoken', token)
  end)
end)
