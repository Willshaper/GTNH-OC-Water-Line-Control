local event = require("event")
local term = require("term")
local keyboard = require("keyboard")

local configManager = require("lib.config-manager.index")
local programController = require("lib.program-controller.index")
local simpleGui = require("lib.simple-gui.index")

local configTemplate = require("src.config-template")
local lineControllerClass = require("src.line-controller")
local scrollList = require("src.gui-widgets.scroll-list")
local formatAmount = require("src.format-amount")

package.loaded.config = nil
local config = require("config")
local version = require("version")

---@type Config
local config = configManager.manager:new(configTemplate):build(config)

local repository = "Willshaper/GTNH-OC-Water-Line-Control"
local archiveName = "WaterLineControl"

local program = programController.program:new(config.enableAutoUpdate, version, repository, archiveName)
local gui = simpleGui.gui:new(program)

local lineController = lineControllerClass:new()

local logo = {
  "__        __    _              _     _               ____            _             _ ",
  "\\ \\      / /_ _| |_ ___ _ __  | |   (_)_ __   ___   / ___|___  _ __ | |_ _ __ ___ | |",
  " \\ \\ /\\ / / _` | __/ _ \\ '__| | |   | | '_ \\ / _ \\ | |   / _ \\| '_ \\| __| '__/ _ \\| |",
  "  \\ V  V / (_| | ||  __/ |    | |___| | | | |  __/ | |__| (_) | | | | |_| | | (_) | |",
  "   \\_/\\_/ \\__,_|\\__\\___|_|    |_____|_|_| |_|\\___|  \\____\\___/|_| |_|\\__|_|  \\___/|_|"
}

local mainTemplate = {
  width = 60,
  background = gui.palette.black,
  foreground = gui.palette.white,
  widgets = {
    logsScrollList = scrollList:new("logs", keyboard.keys.up, keyboard.keys.down)
  },
  lines = {
    "Line State: $lineState$ | QC Mode: $qcMode$",
    "",
    "T1$t1active$ $t1water$ $t1state$",
    "T2$t2active$ $t2water$ $t2state$",
    "T3$t3active$ $t3water$ $t3state$",
    "T4$t4active$ $t4water$ $t4state$",
    "T5$t5active$ $t5water$ $t5state$",
    "T6$t6active$ $t6water$ $t6state$",
    "T7$t7active$ $t7water$ $t7state$",
    "T8$t8active$ $t8water$ $t8state$",
    "BM  $bmWater$",
    "",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#"
  }
}

local controllersStates = {}

for i = 1, 8, 1 do
  local key = "t"..i

  if config.controllers[key] ~= nil then
    controllersStates[key] = "Loading"
  else
    controllersStates[key] = "Unused"
  end
end

local function init()
  gui:setTemplate(mainTemplate)

  term.clear()

  event.push("log_info", "Program started, QC mode "..config.quantityController.controlMode)

  lineController:init(config.controllers)

  for i = 1, 8, 1 do
    local key = "t"..i

    if config.controllers[key] ~= nil then
      config.controllers[key]:init()
    end
  end

  config.quantityController:init(config.controllers)

  -- Stopping the program switches the plant off. The units are chosen above, so the first new cycle uses the right ones
  if config.enableAutoStart ~= false then
    lineController:enable()
  end
end

local function loop()
  while true do
    config.quantityController:loop()
    lineController:loop()

    for i = 1, 8, 1 do
      local key = "t"..i

      if config.controllers[key] ~= nil then
        config.controllers[key]:loop()
        controllersStates[key] = config.controllers[key]:getCurrentState()
      end

      os.sleep(0.1)
    end

    os.sleep(1)
  end
end

---Format the stock and threshold of a fluid read by the Quantity Controller
---@param index integer
---@return string
local function formatWater(index)
  local quantityController = config.quantityController

  if quantityController.controlMode == "disabled" then
    return string.rep(" ", 13)
  end

  return string.format(
    "%6s/%-6s",
    formatAmount(quantityController.waterLevels[index]),
    formatAmount(quantityController.waterThresholds[index])
  )
end

local function guiLoop()
  local values = {
    lineState = lineController:getCurrentState(),
    qcMode = config.quantityController:getCurrentState(),
    bmWater = formatWater(9),
    logs = config.logger.handlers["scrollList"]:getLogs()
  }

  for i = 1, 8, 1 do
    local key = "t"..i

    values[key.."active"] = config.quantityController.isTierActive[i] and "*" or " "
    values[key.."water"] = formatWater(i)
    values[key.."state"] = controllersStates[key]
  end

  gui:render(values)
end

local function onExit()
  lineController:disable()
end

program:registerLogo(logo)
program:registerOnInit(init)
program:registerOnExit(onExit)
program:registerThread(loop)
program:registerTimer(guiLoop, math.huge, 1)
program:start()