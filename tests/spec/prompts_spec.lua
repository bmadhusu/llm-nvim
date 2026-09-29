-- tests/spec/prompts_spec.lua

local spy = require('luassert.spy')

describe('llm.prompts', function()
  local prompts
  local configured
  local errors_mock

  before_each(function()
    configured = nil
    errors_mock = {
      levels = { WARNING = 2 },
      handle = spy.new(function() end),
    }
    package.loaded['llm.config'] = {
      get = function(key)
        if key == 'prompts' then return configured end
      end,
    }
    package.loaded['llm.errors'] = errors_mock
    package.loaded['llm.prompts'] = nil
    prompts = require('llm.prompts')
  end)

  after_each(function()
    package.loaded['llm.config'] = nil
    package.loaded['llm.errors'] = nil
    package.loaded['llm.prompts'] = nil
  end)

  describe('configuration', function()
    it('normalizes a simple string prompt', function()
      configured = { review = "Review this code" }
      assert.are.same({ name = "review", prompt = "Review this code" }, prompts.get("review"))
    end)

    it('normalizes a structured prompt', function()
      configured = { review = { prompt = "Review this code" } }
      assert.are.same({ name = "review", prompt = "Review this code" }, prompts.get("review"))
    end)

    it('dedents and trims multi-line prompts', function()
      configured = {
        review = [[
          Review the code.
            - Be concise.
        ]],
      }
      assert.are.equal("Review the code.\n  - Be concise.", prompts.get("review").prompt)
    end)

    it('returns nothing when no prompts are configured', function()
      assert.is_nil(prompts.get("review"))
      assert.are.same({}, prompts.list())
    end)

    it('ignores invalid definitions with a single warning', function()
      configured = {
        good = "ok",
        missing = { model = "gpt-4o" },
        number = 42,
        ["two words"] = "bad name",
      }
      assert.are.same({ "good" }, prompts.list())
      prompts.list()
      assert.spy(errors_mock.handle).was.called(3)
    end)

    it('picks up a new prompts table after setup is called again', function()
      configured = { review = "one" }
      assert.are.same({ "review" }, prompts.list())
      configured = { tests = "two" }
      assert.are.same({ "tests" }, prompts.list())
    end)
  end)

  describe('get() / exists() / list()', function()
    before_each(function()
      configured = {
        review = "Review this code",
        explain = { prompt = "Explain this code" },
        tests = "Write tests",
      }
    end)

    it('retrieves a prompt by name', function()
      assert.are.equal("Review this code", prompts.get("review").prompt)
      assert.is_nil(prompts.get("missing"))
      assert.is_nil(prompts.get(nil))
    end)

    it('reports existence', function()
      assert.is_true(prompts.exists("review"))
      assert.is_false(prompts.exists("missing"))
    end)

    it('lists prompt names sorted', function()
      assert.are.same({ "explain", "review", "tests" }, prompts.list())
    end)
  end)

  describe('resolve()', function()
    before_each(function()
      configured = { review = "Review this code" }
    end)

    it('resolves a named prompt', function()
      local text, name = prompts.resolve("review")
      assert.are.equal("Review this code", text)
      assert.are.equal("review", name)
    end)

    it('appends additional instructions to a named prompt', function()
      local text, name = prompts.resolve("review focus on error handling")
      assert.are.equal("Review this code\n\nfocus on error handling", text)
      assert.are.equal("review", name)
    end)

    it('tolerates surrounding whitespace', function()
      assert.are.equal("Review this code\n\nextra", (prompts.resolve("  review   extra  ")))
    end)

    it('leaves free-form text unchanged', function()
      local text, name = prompts.resolve("Explain why this function is slow")
      assert.are.equal("Explain why this function is slow", text)
      assert.is_nil(name)
    end)

    it('only matches the first word exactly', function()
      assert.are.equal("reviewer notes", (prompts.resolve("reviewer notes")))
      assert.are.equal("please review", (prompts.resolve("please review")))
    end)
  end)
end)
