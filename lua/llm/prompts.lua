-- llm/prompts.lua - Named (stored) prompts defined in setup({ prompts = ... })
-- License: Apache 2.0
--
-- Prompts may be given as a plain string or as a table with a `prompt` field:
--
--   prompts = {
--     review = "Review this code.",
--     tests = { prompt = "Write tests for this code." },
--   }
--
-- Both forms are normalized to { name = ..., prompt = ... }.

local M = {}
local config = require('llm.config')

-- Normalized prompts are cached per raw config table so that invalid entries
-- are only reported once, not on every completion request.
local cache_source, cache

-- Strip common leading indentation and surrounding blank space, so prompts
-- written as indented [[...]] blocks read naturally.
local function dedent(str)
  local lines = {}
  for line in (str .. "\n"):gmatch("(.-)\r?\n") do
    table.insert(lines, line)
  end

  local indent
  for _, line in ipairs(lines) do
    if line:find("%S") then
      local lead = #line:match("^[ \t]*")
      if not indent or lead < indent then
        indent = lead
      end
    end
  end

  for i, line in ipairs(lines) do
    lines[i] = line:sub((indent or 0) + 1)
  end

  return (table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize(name, def)
  local text = def
  if type(def) == "table" then
    text = def.prompt
  end

  if type(name) ~= "string" or not name:match("^%S+$") or type(text) ~= "string" then
    local errors = require('llm.errors')
    errors.handle('config',
      "Ignoring invalid prompt definition: " .. tostring(name), nil, errors.levels.WARNING)
    return nil
  end

  return { name = name, prompt = dedent(text) }
end

local function all()
  local raw = config.get('prompts')
  if type(raw) ~= "table" then
    return {}
  end

  if raw ~= cache_source then
    cache = {}
    for name, def in pairs(raw) do
      cache[name] = normalize(name, def)
    end
    cache_source = raw
  end

  return cache
end

-- Get a normalized prompt definition by name, or nil if it doesn't exist
function M.get(name)
  if type(name) ~= "string" then
    return nil
  end
  return all()[name]
end

function M.exists(name)
  return M.get(name) ~= nil
end

-- Sorted list of configured prompt names
function M.list()
  local names = {}
  for name in pairs(all()) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

-- Resolve free-form :LLM input.
-- If the first word names a stored prompt, returns the stored prompt text
-- (with any remaining words appended as additional instructions) and the
-- prompt name. Otherwise returns the input unchanged and nil.
function M.resolve(input)
  if type(input) ~= "string" then
    return input, nil
  end

  local name, rest = input:match("^%s*(%S+)%s*(.-)%s*$")
  local def = M.get(name)
  if not def then
    return input, nil
  end

  if rest ~= "" then
    return def.prompt .. "\n\n" .. rest, name
  end
  return def.prompt, name
end

return M
