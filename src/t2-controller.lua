local term = require("term")

local classBuilder = require("lib.class-builder.index")
local componentDiscover = require("lib.component-discover.index")
local gtSensorParser = require("lib.gt-sensor-parser.index")

local baseController = require("src.base-controller")

---@class T2Controller: BaseController
---@field controllerProxy gt_machine
---@field gtSensorParser GtSensorParser
local t2controller = {}

---Constructor
---@return T2Controller
function t2controller:constructor()
  return self
end

---Init
function t2controller:init()
  term.write("Init T2 components: ")
  self:initComponents()
  term.write("ok\n")
end

---Loop
function t2controller:loop()
  self.gtSensorParser:getInformation()
end

---Get current state
---@return string
function t2controller:getCurrentState()
  if self.controllerProxy.isWorkAllowed() == false then
    return "Controller disabled"
  end

  if self.controllerProxy.hasWork() == false then
    return "Wait cycle"
  end

  local successChance = self.gtSensorParser:getNumber(2)

  if successChance == nil then
    successChance = 0
  end

  return "State: [Work] Success: ["..successChance.."%]"
end

---Init components
---@private
function t2controller:initComponents()
  self.controllerProxy = componentDiscover.gtMachine("multimachine.purificationunitozonation")

  if self.controllerProxy == nil then
    error("[T2] Ozonation Purification Unit not found")
  end

  self.gtSensorParser = gtSensorParser.parser:new(self.controllerProxy)
end

return classBuilder.createClass(t2controller, t2controller.constructor, "T2Controller", baseController)
