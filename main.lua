local event = require("event")
local term = require("term")
local keyboard = require("keyboard")
local unicode = require("unicode")

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
    "$header$",
    "$columns$",
    "$t1row$",
    "$t2row$",
    "$t3row$",
    "$t4row$",
    "$t5row$",
    "$t6row$",
    "$t7row$",
    "$t8row$",
    "$bmRow$",
    "&gray;"..string.rep("─", 60),
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "$footer$"
  }
}

---Short names of the control modes, for the header
local modeNames = {
  disabled = "QC off",
  multiThread = "Multi",
  singleThread = "Single",
  singleThreadBalancing = "Balancing"
}

---Width of the cycle progress bar in the header
local barWidth = 10

---Width of the state column, so the stock gauges after it line up
local stateWidth = 22

---Width of the stock gauge at the end of each row
local gaugeWidth = 16

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

---Get the width of a line on the screen, without its colour codes
---@param line string
---@return integer
local function visibleWidth(line)
  return unicode.wlen((line:gsub("&&?[^;]*;", "")))
end

---Header: clock, cycle progress, time to the next cycle and control mode
---@return string
local function renderHeader()
  local progress, maxProgress = lineController:getCycleProgress()
  local bar, cycleText

  if maxProgress > 0 then
    local filled = math.floor(progress / maxProgress * barWidth + 0.5)

    bar = "&&green;"..string.rep(" ", filled).."&&darkSlateGrey;"..string.rep(" ", barWidth - filled).."&&black;"
    cycleText = "&cyan;Next cycle in "..math.ceil((maxProgress - progress) / 20).."s"
  else
    bar = "&&darkSlateGrey;"..string.rep(" ", barWidth).."&&black;"
    cycleText = "&red;Plant stopped"
  end

  local left = "&cyan;"..config.logger:getTime("%H:%M").."  &white;Plant "..bar.."  "..cycleText
  local right = "&lightGray;"..(modeNames[config.quantityController.controlMode] or config.quantityController.controlMode)
  local spaces = math.max(1, mainTemplate.width - visibleWidth(left) - visibleWidth(right))

  return left..string.rep(" ", spaces)..right
end

---Column titles, lined up with renderRow, and the floor and min of singleThreadBalancing
---@return string
local function renderColumns()
  local quantityController = config.quantityController

  if quantityController.controlMode == "disabled" then
    return "&lightGray;"..string.format("%-4s%15s  %s", "Unit", "", "State")
  end

  local left = string.format("%-4s%6s / %-6s  %s", "Unit", "Stock", "Want", "State")
  local right = ""

  if quantityController.controlMode == "singleThreadBalancing" then
    if quantityController.floorQty > 0 then
      right = "Floor "..formatAmount(quantityController.floorQty).."  "
    end

    right = right.."Min "..formatAmount(quantityController.minQty)
  end

  return "&lightGray;"..left..string.rep(" ", math.max(1, mainTemplate.width - #left - #right))..right
end

---Footer: keys, and what the marks mean
---@return string
local function renderFooter()
  return "&lightGray;↑↓ scroll   Q quit   &cyan;▶&lightGray; next cycle   &red;✗&lightGray; admin disabled"
end

---Colour the state of a unit controller
---@param state string
---@return string
local function formatState(state)
  if state == "Controller disabled" then
    return "&lightGray;Idle"
  elseif state == "Wait cycle" then
    return "&white;Waiting"
  elseif state == "Admin disabled" then
    return "&red;✗ Admin disabled"
  elseif state == "Unused" then
    return "&gray;Unused"
  end

  local name, chance = state:match("^State: %[(.-)%] Success: %[([%d%.]+)%%%]$")

  if name == nil then
    return "&white;"..state
  end

  -- A running unit whose dosing is idle still works on its cycle
  local nameText = (name == "Work" or name == "Idle") and "&lime;Working" or "&cyan;"..name
  local chanceNumber = tonumber(chance)
  local chanceColor = chanceNumber >= 90 and "&greenYellow;" or chanceNumber >= 50 and "&yellow;" or "&darkOrange;"

  return nameText.." "..chanceColor..math.floor(chanceNumber).."%"
end

---Get the colour of a stock: red under the floor, orange under min (both only in singleThreadBalancing),
---yellow under the threshold, otherwise green
---@param index integer Index in the Quantity Controller's water levels
---@param isUsed boolean
---@return string
local function stockColor(index, isUsed)
  local quantityController = config.quantityController
  local level = quantityController.waterLevels[index]

  if isUsed == false then
    return "&gray;"
  end

  if quantityController.controlMode == "singleThreadBalancing" then
    if level < quantityController.floorQty then
      return "&red;"
    elseif level < quantityController.minQty then
      return "&darkOrange;"
    end
  end

  if quantityController:isCapped(index) and level < quantityController.waterThresholds[index] then
    return "&yellow;"
  end

  return "&green;"
end

---Get the largest stock of the waters whose unit is used, the scale of gauges without a cap
---@return number
local function largestStock()
  local largest = 0

  for index = 1, 9 do
    if config.controllers["t"..math.min(index, 8)] ~= nil then
      largest = math.max(largest, config.quantityController.waterLevels[index])
    end
  end

  return largest
end

---Half height bar of a stock, from 0 to its threshold (or the largest stock without a cap), like the cycle bar
---@param index integer Index in the Quantity Controller's water levels
---@param isUsed boolean
---@param color string
---@return string
local function renderGauge(index, isUsed, color)
  local quantityController = config.quantityController

  if quantityController.controlMode == "disabled" or isUsed == false then
    return ""
  end

  local scale = quantityController:isCapped(index) and quantityController.waterThresholds[index] or largestStock()
  local filled = 0

  if scale > 0 then
    filled = math.min(gaugeWidth, math.floor(quantityController.waterLevels[index] / scale * gaugeWidth + 0.5))
  end

  return color..string.rep("▄", filled).."&darkSlateGrey;"..string.rep("▄", gaugeWidth - filled)
end

---A row of the table: next-cycle mark, unit, stock / want and state
---@param label string
---@param index integer Index in the Quantity Controller's water levels
---@param tier integer The tier which makes the fluid
---@return string
local function renderRow(label, index, tier)
  local quantityController = config.quantityController
  local isUsed = config.controllers["t"..tier] ~= nil
  local marker = (index <= 8 and quantityController.isTierActive[index]) and "&cyan;▶" or " "
  local water = string.rep(" ", 15)
  local color = stockColor(index, isUsed)

  if quantityController.controlMode ~= "disabled" then
    local want = quantityController:isCapped(index) and formatAmount(quantityController.waterThresholds[index]) or "-"

    water = color..string.format("%6s", formatAmount(quantityController.waterLevels[index]))
      .."&lightGray; / "..(isUsed and "&lightGray;" or "&gray;")..string.format("%-6s", want)
  end

  local state = index <= 8 and formatState(controllersStates["t"..index]) or ""
  local statePadding = string.rep(" ", math.max(0, stateWidth - visibleWidth(state)))

  return marker..(isUsed and "&white;" or "&gray;")..string.format("%-3s", label)..water.."  "
    ..state..statePadding.." "..renderGauge(index, isUsed, color)
end

local function guiLoop()
  local values = {
    header = renderHeader(),
    columns = renderColumns(),
    footer = renderFooter(),
    bmRow = renderRow("BM", 9, 8),
    logs = config.logger.handlers["scrollList"]:getLogs()
  }

  for i = 1, 8, 1 do
    values["t"..i.."row"] = renderRow("T"..i, i, i)
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