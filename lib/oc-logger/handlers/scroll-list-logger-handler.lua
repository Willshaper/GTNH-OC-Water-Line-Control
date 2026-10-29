local classBuilder = require("lib.class-builder.index")
local tableUtilities = require("lib.table-utilities.index")

---@class ScrollListLoggerHandler
---@field logs table<string>
---@field lastMessage string|nil
---@field repeatCount number
local scrollListLoggerHandler = {}

---Constructor
---@param logLevel "debug"|"info"|"warning"|"error"
---@param logListSize number
---@param messageFormat? string
---@return ScrollListLoggerHandler
function scrollListLoggerHandler:constructor(logLevel, logListSize, messageFormat)

  self.logLevel = logLevel
  self.logListSize = logListSize

  self.messageFormat = messageFormat or "{Message}"
  self.logs = {}

  self.lastMessage = nil
  self.repeatCount = 0

  return self
end

---Log
---@param logger Logger
---@param level "debug"|"info"|"warning"|"error"
---@param message string
---@param rawMessage? string
function scrollListLoggerHandler:log(logger, level, message, rawMessage)
  local line = nil

  if level == "debug" then
    line = "&lightBlue;"..message.."&white;"
  elseif level == "info" then
    line = message
  elseif level == "warning" then
    line = "&yellow;"..message.."&white;"
  elseif level == "error" then
    line = "&red;[Error] "..message.."&white;"
  end

  if line == nil then
    return
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