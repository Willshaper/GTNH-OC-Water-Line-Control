local event = require("event")
local thread = require("thread")
local component = require("component")
local computer = require("computer")
local keyboard = require("keyboard")
local term = require("term")

local classBuilder = require("lib.class-builder.index")
local programUpdater = require("lib.program-controller.program-updater")

---Try Catch. An error is pushed as "program_error" with the run it happened in, so the program can recover
---@param callback function
---@param runId? integer
---@return function
local function try(callback, runId)
  return function(...)
    local result = table.pack(xpcall(callback, debug.traceback, ...))
    if not result[1] then
      event.push("program_error", result[2], runId)
    end
    return table.unpack(result, 2, result.n)
  end
end

---Only "exit" and "program_error". event.pull matches names as patterns, so "exit" would also catch "thread_exit"
---@param name any
---@return boolean
local function isProgramSignal(name)
  return name == "exit" or name == "program_error"
end

---Get the first line of an error
---@param message any
---@return string
local function firstLine(message)
  return (tostring(message):match("^[^\n]*"))
end

---@class Program
---@field enableAutoUpdate? boolean
---@field version? ProgramVersion
---@field repository? string
---@field archiveName? string
---@field debug boolean
---@field coroutines table
---@field running table
---@field keyHandlers table<number, fun()>
---@field keyListener? number
---@field runId integer
---@field runStartedAt number
---@field failingSince? number
---@field retrySeconds number
---@field giveUpSeconds number
---@field defaultLoopInterval number
---@field defaultWidth number
---@field defaultHeight number
---@field defaultForeground number
---@field defaultBackground number
---@field logo? string[]
---@field onInit? fun()
---@field onStop? fun()
---@field onExit? fun()
---@field updater ProgramUpdater
local program = {}

---Constructor
---@param enableAutoUpdate? boolean
---@param version? ProgramVersion
---@param repository? string
---@param archiveName? string
---@return Program
function program:constructor(enableAutoUpdate, version, repository, archiveName)
  self.enableAutoUpdate = enableAutoUpdate
  self.version = version
  self.repository = repository
  self.archiveName = archiveName

  self.debug = false
  self.coroutines = {}
  self.running = {}
  self.keyHandlers = {}
  self.keyListener = nil

  self.runId = 0
  self.runStartedAt = 0
  self.failingSince = nil

  -- After an error the program starts again after retrySeconds. It gives up when it is still failing after giveUpSeconds
  self.retrySeconds = 30
  self.giveUpSeconds = 300

  self.defaultLoopInterval = 1/20
  self.defaultWidth = 0
  self.defaultHeight = 0
  self.defaultForeground = 0
  self.defaultBackground = 0

  self.logo = nil

  self.onInit = nil
  self.onStop = nil
  self.onExit = nil

  self.updater = programUpdater:new(self)

  return self
end

---Register logo
---@param logo string[]
function program:registerLogo(logo)
  self.logo = logo
end

---Register onInit function. It runs at the start, and again when the program starts again after an error
---@param callback function
function program:registerOnInit(callback)
  self.onInit = callback
end

---Register onStop function. It runs when a run of the program stops, after an error and before onExit
---@param callback function
function program:registerOnStop(callback)
  self.onStop = callback
end

---Register onExit function
---@param callback function
function program:registerOnExit(callback)
  self.onExit = callback
end

---Register timer
---@param callback function
---@param times? number
---@param interval? number
function program:registerTimer(callback, times, interval)
  interval = interval or self.defaultLoopInterval

  local coroutineDescriptor = {
    type = "timer",
    interval = interval,
    callback = callback,
    times = times
  }

  table.insert(self.coroutines, coroutineDescriptor)
end

---Register thread
---@param callback function
function program:registerThread(callback)
  local coroutineDescriptor = {
    type = "thread",
    callback = callback,
  }

  table.insert(self.coroutines, coroutineDescriptor)
end

---Register button handler
---@param keyCode number
---@param callback function
function program:registerKeyHandler(keyCode, callback)
  if self.keyHandlers[keyCode] ~= nil then
    error("[Program] "..keyCode.." key is busy")
  end

  self.keyHandlers[keyCode] = try(callback)
end

---Remove button handler
---@param keyCode number
function program:removeKeyHandler(keyCode)
  self.keyHandlers[keyCode] = nil
end

---Program start
function program:start()
  self.defaultWidth, self.defaultHeight = component.gpu.getResolution()
  self.defaultForeground = component.gpu.getForeground()
  self.defaultBackground = component.gpu.getBackground()

  if self.logo then
    self:displayLogo()
  end

  if self.enableAutoUpdate then
    self.updater:autoUpdate()
    self:registerTimer(self.updater:checkUpdateTimer())
  end

  self:registerKeyHandler(keyboard.keys.q, function()
    event.push("exit")
  end)

  self.keyListener = event.listen("key_up", try(function (_, address, char, keyCode)
    if self.debug == true then
      event.push("log_debug", "Pressed ["..string.char(char).."]: "..keyCode.."\n")
    end

    if self.keyHandlers[keyCode] then
      if self.debug == true then
        event.push("log_debug", "Action ["..string.char(char).."]: "..keyCode.."\n");
      end

      self.keyHandlers[keyCode]()
    end
  end))

  self:runUntilExit()
end

---Run the program, start it again after an error, and exit on Q or when it keeps failing
---@private
function program:runUntilExit()
  local isRunning, problem = self:startRun()

  while true do
    if isRunning then
      local name, message, runId = event.pullFiltered(isProgramSignal)

      if name == "exit" then
        self:exit(message)
        return
      end

      -- An error from a run that already stopped is ignored
      if runId == nil or runId == self.runId then
        -- A run that went well for a while starts a new count
        if computer.uptime() - self.runStartedAt >= self.giveUpSeconds then
          self.failingSince = nil
        end

        self:stopRun()
        isRunning, problem = false, message
      end
    else
      local now = computer.uptime()
      self.failingSince = self.failingSince or now
      local giveUpIn = self.giveUpSeconds - (now - self.failingSince)

      if giveUpIn <= 0 then
        event.push("log_error", "[Program] Still failing after "..math.floor(self.giveUpSeconds / 60).." min, stopping")
        self:exit(problem)
        return
      end

      event.push("log_error", "[Program] Error, restarting in "..self.retrySeconds.."s: "..firstLine(problem))
      self:showError(problem, giveUpIn)

      if self:waitForExit(self.retrySeconds) then
        self:exit()
        return
      end

      isRunning, problem = self:startRun()

      if isRunning then
        event.push("log_warning", "[Program] Started again after an error")
      end
    end
  end
end

---Start a run: onInit, then the timers and threads
---@return boolean isRunning
---@return string? problem
---@private
function program:startRun()
  self.runId = self.runId + 1
  self.runStartedAt = computer.uptime()

  if self.onInit then
    local isOk, problem = xpcall(self.onInit, debug.traceback)

    if not isOk then
      self:stopRun()
      return false, problem
    end
  end

  for _, descriptor in ipairs(self.coroutines) do
    if descriptor.type == "timer" then
      table.insert(self.running, event.timer(descriptor.interval, try(descriptor.callback, self.runId), descriptor.times))
    elseif descriptor.type == "thread" then
      local handle = thread.create(try(descriptor.callback, self.runId))
      handle:detach()
      table.insert(self.running, handle)
    end
  end

  return true, nil
end

---Stop the timers and threads of a run, then onStop
---@private
function program:stopRun()
  for _, handle in ipairs(self.running) do
    if type(handle) == "table" and handle.kill then
      handle:kill()
    elseif type(handle) == "number" then
      event.cancel(handle)
    end
  end

  self.running = {}

  if self.onStop then
    pcall(self.onStop)
  end
end

---Wait, and return true if Q was pressed
---@param seconds number
---@return boolean
---@private
function program:waitForExit(seconds)
  local deadline = computer.uptime() + seconds

  while computer.uptime() < deadline do
    local name = event.pullFiltered(deadline - computer.uptime(), isProgramSignal)

    if name == "exit" then
      return true
    end
  end

  return false
end

---Show an error and when the program starts again
---@param problem any
---@param giveUpIn number
---@private
function program:showError(problem, giveUpIn)
  component.gpu.freeAllBuffers()
  component.gpu.setResolution(self.defaultWidth, self.defaultHeight)
  component.gpu.setForeground(0xFF5555)
  component.gpu.setBackground(self.defaultBackground)
  term.clear()

  term.write("Error, starting again in "..self.retrySeconds.."s.\n")
  term.write("If it still fails in "..math.ceil(giveUpIn / 60).." min, it switches the plant off and stops.\n")
  term.write("Press Q to stop now.\n\n")

  local lineCount = 0

  for line in tostring(problem):gmatch("[^\n]+") do
    term.write(line.."\n")
    lineCount = lineCount + 1

    if lineCount >= 8 then
      break
    end
  end

  component.gpu.setForeground(self.defaultForeground)
end

---Program exit
---@param exception any
function program:exit(exception)
  self:stopRun()

  if self.keyListener then
    event.cancel(self.keyListener)
    self.keyListener = nil
  end

  component.gpu.freeAllBuffers()
  component.gpu.setResolution(self.defaultWidth, self.defaultHeight)
  component.gpu.setForeground(self.defaultForeground)
  component.gpu.setBackground(self.defaultBackground)

  term.clear()

  if exception then
    event.push("log_error", exception)
  end

  -- Hand out the log lines while the logger still listens; onExit stops it
  os.sleep(0)

  if self.onExit then
    pcall(self.onExit)
  end

  if exception then
    io.stderr:write(tostring(exception))
    os.exit(1)
  else
    os.exit(0)
  end
end

---Display logo
---@private
function program:displayLogo()
  local width = #self.logo[1] + 2
  local height = #self.logo + 2

  component.gpu.setResolution(width, height)
  component.gpu.fill(1, 1, width, height, " ")

  term.setCursor(1, 2)

  for _, line in pairs(self.logo) do
    term.write(" "..line.."\n")
  end

  os.sleep(1)

  component.gpu.fill(1, 1, width, height, " ")
  component.gpu.setResolution(self.defaultWidth, self.defaultHeight)
end

return classBuilder.createClass(program, program.constructor, "Program")
