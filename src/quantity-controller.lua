local event = require("event")
local term = require("term")

local classBuilder = require("lib.class-builder.index")
local componentDiscover = require("lib.component-discover.index")

---Fluids read from the ME network. Index 9 (Stabilised Baryonic Matter) is made by T8
local fluidNames = {
  "grade1purifiedwater",
  "grade2purifiedwater",
  "grade3purifiedwater",
  "grade4purifiedwater",
  "grade5purifiedwater",
  "grade6purifiedwater",
  "grade7purifiedwater",
  "grade8purifiedwater",
  "stablebaryonicmatter",
}

---Get the tier which makes the fluid at an index of fluidNames
---@param index integer
---@return integer
local function tierOf(index)
  return math.min(index, 8)
end

---@alias QuantityControlMode "disabled"|"multiThread"|"singleThread"|"singleThreadBalancing"

---@class QuantityController
---@field controlMode QuantityControlMode
---@field meInterfaceAddress string
---@field minQty number
---@field waterThresholds number[]
---@field controllers ControllersConfig
---@field meInterfaceProxy me_interface
---@field waterLevels number[]
---@field isTierActive boolean[]
local quantityController = {}

---Constructor
---@param controlMode QuantityControlMode
---@param meInterfaceAddress string
---@param minQty number
---@param waterThresholds number[]
---@return QuantityController
function quantityController:constructor(controlMode, meInterfaceAddress, minQty, waterThresholds)
  self.controlMode = controlMode
  self.meInterfaceAddress = meInterfaceAddress
  self.minQty = minQty
  self.waterThresholds = waterThresholds

  self.waterLevels = {0, 0, 0, 0, 0, 0, 0, 0, 0}
  self.isTierActive = {false, false, false, false, false, false, false, false}

  return self
end

---Init
---@param controllers ControllersConfig
function quantityController:init(controllers)
  self.controllers = controllers

  if self.controlMode == "disabled" then
    return
  end

  term.write("Init Quantity Controller: ")
  self.meInterfaceProxy = componentDiscover.proxy(self.meInterfaceAddress, "me_interface", "[QC] ME Interface")

  event.listen("cycle_pre_end", function (_, isLate)
    if isLate == true then
      event.push("log_debug", "[QC] Cycle end seen late, the units chosen now start one cycle later")
    end

    self:updateWaterLevels()
    self:updateControllerEnablement()
  end)

  -- Enable the right units now, so the next cycle doesn't start every unit that was left on
  self:updateWaterLevels()
  self:updateControllerEnablement()
  term.write("ok\n")
end

---Loop
function quantityController:loop()
  self:checkAdminResets()

  if self.controlMode == "disabled" then
    return
  end

  self:updateWaterLevels()
end

---Let units that were enabled by hand after a fault be used again
---@private
function quantityController:checkAdminResets()
  for tier = 1, 8 do
    local controller = self.controllers["t"..tier]

    if controller ~= nil and controller:checkAdminReset() then
      event.push("log_info", "[T"..tier.."] Enabled by hand, no longer admin disabled")

      -- The Quantity Controller decides when it runs again, so two units never start in the same cycle
      if self.controlMode ~= "disabled" then
        controller:setEnabled(self.isTierActive[tier])
      end
    end
  end
end

---Get current control mode
---@return string
function quantityController:getCurrentState()
  return self.controlMode
end

---Check if the tier has a working controller the Quantity Controller may enable
---@param tier integer
---@return boolean
---@private
function quantityController:isTierUsable(tier)
  local controller = self.controllers["t"..tier]

  return controller ~= nil and controller.isAdminEnabled
end

---Check if the fluid at an index of fluidNames is below its threshold
---@param index integer
---@return boolean
---@private
function quantityController:isBelowThreshold(index)
  return self.waterLevels[index] < self.waterThresholds[index]
end

---Choose which tiers run in the next cycle and enable only those
function quantityController:updateControllerEnablement()
  if self.controlMode == "disabled" then
    return
  end

  local isTierActive = {false, false, false, false, false, false, false, false}

  if self.controlMode == "multiThread" then
    -- Every tier below its threshold runs
    for tier = 1, 8 do
      if self:isTierUsable(tier) then
        isTierActive[tier] = self:isBelowThreshold(tier) or (tier == 8 and self:isBelowThreshold(9))
      end
    end
  elseif self.controlMode == "singleThread" then
    -- The lowest tier below its threshold runs
    for index = 1, 9 do
      if self:isTierUsable(tierOf(index)) and self:isBelowThreshold(index) then
        isTierActive[tierOf(index)] = true
        break
      end
    end
  elseif self.controlMode == "singleThreadBalancing" then
    -- The tier with the least water (below its threshold) runs, lower tiers win ties.
    -- A tier below minQty runs first, so higher tiers never start without enough input
    local winner = nil

    for index = 1, 9 do
      if self:isTierUsable(tierOf(index)) and self:isBelowThreshold(index) then
        local isBelowMinQty = self.waterLevels[index] < self.minQty

        if winner == nil or self.waterLevels[index] < self.waterLevels[winner] or isBelowMinQty then
          winner = index

          if isBelowMinQty then
            break
          end
        end
      end
    end

    if winner ~= nil then
      isTierActive[tierOf(winner)] = true
    end
  end

  self.isTierActive = isTierActive

  -- Disable every unit before enabling any, so two units never start in the same cycle
  for tier = 1, 8 do
    if self.controllers["t"..tier] ~= nil then
      self.controllers["t"..tier]:setEnabled(false)
    end
  end

  for tier = 1, 8 do
    if self.controllers["t"..tier] ~= nil and isTierActive[tier] then
      self.controllers["t"..tier]:setEnabled(true)
    end
  end
end

---Read the amount of each water grade and Stabilised Baryonic Matter in the ME network
---@private
function quantityController:updateWaterLevels()
  local waterLevels = {0, 0, 0, 0, 0, 0, 0, 0, 0}
  local fluids = self.meInterfaceProxy.getFluidsInNetwork() or {}

  for _, fluid in ipairs(fluids) do
    for index, fluidName in ipairs(fluidNames) do
      if fluid.name == fluidName then
        waterLevels[index] = fluid.amount or 0
      end
    end
  end

  self.waterLevels = waterLevels
end

return classBuilder.createClass(quantityController, quantityController.constructor, "QuantityController")
