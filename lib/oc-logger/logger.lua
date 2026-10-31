local filesystem = require("filesystem")
local event = require("event")
local computer = require("computer")

local classBuilder = require("lib.class-builder.index")
local stringUtilities = require("lib.string-utilities.index")

local logLevels = {debug = 0, info = 1, warning = 2, error = 3}

---Seconds between reads of the real clock, which writes a file. In between it counts on from the uptime
local clockReadSeconds = 30

---@class Logger
---@field timeCorrection number
---@field handlers table<string, LoggerHandler>
---@field listenerIds number[]
---@field clock? number Real time in seconds when the clock was last read
---@field clockReadAt? number Uptime when the clock was last read
local logger = {}

---@return Logger
---@param name string
---@param timeZone number
---@param handlers table<string, LoggerHandler>
function logger:constructor(name, timeZone, handlers)
  self.timeCorrection = timeZone * 3600
  self.name = name
  self.handlers = handlers
  self.listenerIds = {}

  for _, level in ipairs({"debug", "info", "warning", "error"}) do
    local id = event.listen("log_"..level, function (_, ...)
      self:log(level, ...)
    end)

    if id then
      table.insert(self.listenerIds, id)
    end
  end

  return self
end

---Stop listening to log events. OpenOS keeps a program's listeners after it ends
function logger:stop()
  for _, id in ipairs(self.listenerIds) do
    event.cancel(id)
  end

  self.listenerIds = {}
end

---Format logger message
---@param format string
---@param logLevel "debug"|"info"|"warning"|"error"
---@param message string
---@return string
---@private
function logger:formatMessage(format, logLevel, message)
  local result = format

  local timeFormat = format:match("{Time:([^}]+)}")

  result = result:gsub("{Message}", message)
  result = result:gsub("{LogLevel}", logLevel)
  result = result:gsub("{Time:[^}]+}", self:getTime(timeFormat))

  return result
end

---Get handler be name
---@param name string
---@return LoggerHandler
function logger:getLogger(name)
  return self.handlers[name]
end

---Log
---@param logLevel "debug"|"info"|"warning"|"error"
---@param ... any
function logger:log(logLevel, ...)
  local message = ""

  local args = {...}

  for key, _ in ipairs(args) do
    local serialized = stringUtilities.objectToString(args[key]):gsub("^['\"]", ""):gsub("['\"]$", "")
    message = message..serialized
  end

  for _, handler in pairs(self.handlers) do
    if logLevels[logLevel] >= logLevels[handler.logLevel] then
      local formatted = self:formatMessage(handler.messageFormat, logLevel, message)
      handler:log(self, logLevel, formatted, message)
    end
  end
end

---Debug
---@param ... any
function logger:debug(...)
  self:log("debug", ...)
end

---Info
---@param ... any
function logger:info(...)
  self:log("info", ...)
end

---Warning
---@param ... any
function logger:warning(...)
  self:log("warning", ...)
end

---Error
---@param ... any
function logger:error(...)
  self:log("error", ...)
end

---Get real time
---@param format string|nil
---@return string
---@private
function logger:getTime(format)
  format = format or "%d.%m.%Y %H:%M:%S"

  local now = computer.uptime()

  if self.clockReadAt == nil or now - self.clockReadAt >= clockReadSeconds or now < self.clockReadAt then
    local file = assert(io.open("/tmp/unix.tmp", "w"))

    file:write("")
    file:close()

    self.clock = tonumber(string.sub(filesystem.lastModified("/tmp/unix.tmp"), 1, -4))
    self.clockReadAt = now
  end

  local lastModified = self.clock + math.floor(now - self.clockReadAt) + self.timeCorrection
  local dateTime = tostring(os.date(format, lastModified))
  return dateTime
end

return classBuilder.createClass(logger, logger.constructor, "Logger")