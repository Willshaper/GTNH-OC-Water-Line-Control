local term = require("term")

local classBuilder = require("lib.class-builder.index")
local componentDiscover = require("lib.component-discover.index")
local gtSensorParser = require("lib.gt-sensor-parser.index")

local baseController = require("src.base-controller")

---@class T1Controller: BaseController
---@field controllerProxy gt_machine
---@field gtSensorParser GtSensorParser
local t1controller = {}

---Constructor
---@return T1Controller
function t1controller:constructor()
  return self
end

---Init
function t1controller:init()
  term.write("Init T1 components: ")
  self:initComponents()
  term.write("ok\n")
end

---Loop
function t1controller:loop()
  self.gtSensorParser:getInformation()
end

---Get current state
---@return string
function t1controller:getCurrentState()
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
function t1controller:initComponents()
  self.controllerProxy = componentDiscover.gtMachine("multimachine.purificationunitclarifier")

  if self.controllerProxy == nil then
    error("[T1] Clarifier Purification Unit not found")
  end

  self.gtSensorParser = gtSensorParser.parser:new(self.controllerProxy)
end

return classBuilder.createClass(t1controller, t1controller.constructor, "T1Controller", baseController)
