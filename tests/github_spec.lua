local gh = require("gh-actions.github")

describe("get_github_token", function()
  it("it should read from gh/hosts.yml", function()
    local token = gh.get_github_token("tests/fixtures/gh_hosts.yml")

    assert.are.same(token, "topaxitesttoken")
  end)
end)
