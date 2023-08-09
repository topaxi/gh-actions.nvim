local gh = require("gh-actions.github")

describe("get_github_token", function()
  before_each(function()
    vim.env.GITHUB_TOKEN = nil
  end)

  it("should read from gh/hosts.yml", function()
    local token = gh.get_github_token("echo etopaxitesttoken")

    assert.are.same("topaxitesttoken", token)
  end)

  it("should read from GITHUB_TOKEN", function()
    vim.env.GITHUB_TOKEN = "envtoken"

    local token = gh.get_github_token("echo etopaxitesttoken")

    assert.are.same("envtoken", token)
  end)
end)
