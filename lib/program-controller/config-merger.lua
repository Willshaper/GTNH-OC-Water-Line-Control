-- Carries the values of an old config.lua into the config.lua of a new version: the new file's layout,
-- comments and new settings, with the player's values. Used by setup.lua and the auto update.
local merger = {}

---Settings that mean something when they are left out of config.lua. When the old file doesn't have them,
---they get the value that keeps what the program did, not the new default
local whenMissing = {
  {pattern = "^quantityController%.floorQty$", value = 0, why = "0 is no floor stage, as before"},
  {pattern = "^quantityController%.waterThresholds%.", value = 0, why = "0 is no cap, as before"},
}

---Old settings whose value moved to a new place
local moved = {
  {from = "logger.handlers.discord.discordWebhookUrl", to = "discord.webhookUrl"},
}

---Split a line into its code and its comment, without looking inside strings
---@param line string
---@return string code
---@return string comment
local function splitComment(line)
  local quote = nil
  local i = 1

  while i <= #line do
    local char = line:sub(i, i)

    if quote then
      if char == "\\" then
        i = i + 1
      elseif char == quote then
        quote = nil
      end
    elseif char == '"' or char == "'" then
      quote = char
    elseif line:sub(i, i + 1) == "--" then
      return line:sub(1, i - 1), line:sub(i)
    end

    i = i + 1
  end

  return line, ""
end

---Write a value as Lua
---@param value any
---@return string|nil
local function serialize(value)
  local kind = type(value)

  if kind == "string" then
    return (string.format("%q", value):gsub("\\\n", "\\n"))
  elseif kind == "number" then
    if value == math.floor(value) and math.abs(value) < 2^53 then
      return string.format("%d", value)
    end

    return string.format("%.14g", value)
  elseif kind == "boolean" then
    return tostring(value)
  end

  return nil
end

---Get a value by its path, e.g. "quantityController.minQty"
---@param root table
---@param path string
---@return any
local function lookup(root, path)
  local value = root

  for key in path:gmatch("[^%.]+") do
    if type(value) ~= "table" then
      return nil
    end

    value = value[key]
  end

  return value
end

---Read config.lua in a sandbox
---@param text string
---@return table|nil config
---@return string|nil problem
function merger.load(text)
  local chunk, problem = load(text, "=config.lua", "t", {})

  if not chunk then
    return nil, problem
  end

  local isOk, result = pcall(chunk)

  if not isOk then
    return nil, tostring(result)
  end

  if type(result) ~= "table" then
    return nil, "config.lua doesn't return a table"
  end

  return result, nil
end

---Merge the values of the old config.lua into the new one
---@param oldText string The player's config.lua
---@param newText string The config.lua of the new version
---@return string|nil merged
---@return table|string report {carried, added = {{path, value, why}}, removed = {path}, moved = {{from, to}}}, or why it failed
function merger.merge(oldText, newText)
  local old, problem = merger.load(oldText)

  if not old then
    return nil, "your config.lua can't be read: "..tostring(problem)
  end

  local report = {carried = 0, added = {}, removed = {}, moved = {}}
  local templatePaths = {}
  local stack = {}
  local lines = {}
  local isInConfig = false

  -- Values that moved: read from the old place, used at the new place unless that already has a value
  local movedValues = {}

  for _, each in ipairs(moved) do
    local value = lookup(old, each.from)
    local current = lookup(old, each.to)

    if value ~= nil and value ~= "" and (current == nil or current == "") then
      movedValues[each.to] = value
      table.insert(report.moved, {from = each.from, to = each.to})
    end
  end

  local function pathOf(key)
    if #stack == 0 then
      return key
    end

    return table.concat(stack, ".").."."..key
  end

  for line in (newText.."\n"):gmatch("(.-)\r?\n") do
    local code, comment = splitComment(line)
    local result = line

    if not isInConfig then
      if code:match("^%s*local%s+config%s*=%s*{%s*$") then
        isInConfig = true
      end
    elseif code:match("^%s*}%s*,?%s*$") then
      if #stack == 0 then
        isInConfig = false
      else
        table.remove(stack)
      end
    else
      local key = code:match("^%s*([%w_]+)%s*=%s*{%s*$") or code:match('^%s*%["([^"]+)"%]%s*=%s*{%s*$')

      if key then
        table.insert(stack, key)
        templatePaths[pathOf("")] = true
      else
        local indent, leaf, value, comma = code:match("^(%s*)([%w_]+)%s*=%s*(.-)(,?)%s*$")

        if leaf and value ~= "" then
          local path = pathOf(leaf)
          local oldValue = movedValues[path]

          if oldValue == nil then
            oldValue = lookup(old, path)
          end

          templatePaths[path] = true

          if oldValue == nil then
            -- A setting the old file doesn't have
            local written = value

            for _, rule in ipairs(whenMissing) do
              if path:match(rule.pattern) then
                written = serialize(rule.value)
                table.insert(report.added, {path = path, value = written, why = rule.why})
                break
              end
            end

            if written == value then
              table.insert(report.added, {path = path, value = value})
            end

            value = written
          else
            local text = serialize(oldValue)

            if text then
              value = text
              report.carried = report.carried + 1
            end
          end

          result = indent..leaf.." = "..value..comma..(comment ~= "" and (" "..comment) or "")
        end
      end
    end

    table.insert(lines, result)
  end

  -- Old settings the new version doesn't have
  local function findRemoved(value, path)
    if type(value) == "table" then
      if path ~= "" and not templatePaths[path] and not templatePaths[path.."."] then
        table.insert(report.removed, path)
        return
      end

      local keys = {}

      for key in pairs(value) do
        table.insert(keys, key)
      end

      table.sort(keys, function (a, b) return tostring(a) < tostring(b) end)

      for _, key in ipairs(keys) do
        findRemoved(value[key], path == "" and tostring(key) or (path.."."..tostring(key)))
      end
    elseif not templatePaths[path] then
      table.insert(report.removed, path)
    end
  end

  findRemoved(old, "")

  -- The last newline was added for reading
  if lines[#lines] == "" then
    table.remove(lines)
  end

  local merged = table.concat(lines, "\n")

  if not newText:find("\n$") then
    return merged, report
  end

  return merged.."\n", report
end

---Lines that describe a merge for the player
---@param report table
---@return string[]
function merger.describe(report)
  local lines = {}

  table.insert(lines, "Kept "..report.carried.." of your settings.")

  for _, each in ipairs(report.moved) do
    table.insert(lines, "Moved "..each.from.." to "..each.to..".")
  end

  if #report.added > 0 then
    table.insert(lines, "New settings:")

    for _, each in ipairs(report.added) do
      table.insert(lines, "  "..each.path.." = "..each.value..(each.why and (" ("..each.why..")") or ""))
    end
  end

  if #report.removed > 0 then
    table.insert(lines, "No longer used, left out: "..table.concat(report.removed, ", "))
  end

  return lines
end

return merger
