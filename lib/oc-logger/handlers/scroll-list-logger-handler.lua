local classBuilder = require("lib.class-builder.index")
local tableUtilities = require("lib.table-utilities.index")

---@class ScrollListLoggerHandler
---@field logs table<string>
---@field lastMessage string|nil
---@field repeatCount number
---@field tagColors table<string, string>
local scrollListLoggerHandler = {}

---Constructor
---@param logLevel "debug"|"info"|"warning"|"error"
---@param logListSize number
---@param messageFormat? string
---@param tagColors? table<string, string> Colours for info messages starting with a tag, e.g. {["[QC]"] = "cyan"}
---@return ScrollListLoggerHandler
function scrollListLoggerHandler:constructor(logLevel, logListSize, messageFormat, tagColors)

  self.logLevel = logLevel
  self.logListSize = logListSize

  self.messageFormat = messageFormat or "{Message}"
  self.logs = {}

  self.lastMessage = nil
  self.repeatCount = 0
  self.tagColors = tagColors or {}

  return self
end

---Log
---@param logger Logger
---@param level "debug"|"info"|"warning"|"error"
---@param message string
---@param rawMessage? string
function scrollListLoggerHandler:log(logger, level, message, rawMessage)
  local color = nil

  if level == "debug" then
    color = "&lightGray;"
  elseif level == "info" then
    color = "&white;"

    for tag, tagColor in pairs(self.tagColors) do
      if rawMessage ~= nil and rawMessage:sub(1, #tag) == tag then
        color = "&"..tagColor..";"
      end
    end
  elseif level == "warning" then
    color = "&yellow;"
  elseif level == "error" then
    color = "&red;[Error] "
  end

  if color == nil then
    return
  end

  -- The part of the format before the message (the time) is dimmed, the message gets the colour
  local line = color..message.."&white;"

  if rawMessage ~= nil and #message > #rawMessage and message:sub(-#rawMessage) == rawMessage then
    line = "&lightGray;"..message:sub(1, #message - #rawMessage)..color..rawMessage.."&white;"
  end

  -- The same message again replaces the newest line with a count, so repeats don't push other lines off the screen
  local key = level..":"..(rawMessage or message)

  if key == self.lastMessage and #self.logs > 0 then
    self.repeatCount = self.repeatCount + 1
    self.logs[1] = line:gsub("&white;$", "").." (x"..self.repeatCount..")&white;"
    return
  end

  self.lastMessage = key
  self.repeatCount = 1
  tableUtilities.pushFront(self.logs, line, self.logListSize)
end

---Get logs list
function scrollListLoggerHandler:getLogs()
  return self.logs
end

---Clear logs list
function scrollListLoggerHandler:clearLogs()
  tableUtilities.clear(self.logs)
  self.lastMessage = nil
end

return classBuilder.createClass(scrollListLoggerHandler, scrollListLoggerHandler.constructor, "ScrollListLoggerHandler")