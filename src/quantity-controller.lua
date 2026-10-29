local event = require("event")
local term = require("term")

local classBuilder = require("lib.class-builder.index")
local componentDiscover = require("lib.component-discover.index")

local formatAmount = require("src.format-amount")

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

---Get the short name of the fluid at an index of fluidNames, for the log
---@param index integer
---@return string
local function fluidLabel(index)
  return index == 9 and "BM" or "G"..index
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
---@field lastDecision string|nil
---@field isAdminDisableLogged boolean[]
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
  self.lastDecision = nil
  self.isAdminDisableLogged = {}

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
  self:checkAdminStates()

  if self.controlMode == "disabled" then
    return
  end

  self:updateWaterLevels()
end

---Log units that were admin disabled after a fault, and let units that were enabled by hand be used again
---@private
function quantityController:checkAdminStates()
  for tier = 1, 8 do
    local controller = self.controllers["t"..tier]

    if controller ~= nil and controller:checkAdminReset() then
      event.push("log_info", "[T"..tier.."] Enabled by hand, no longer admin disabled")
      self.isAdminDisableLogged[tier] = false

      -- The Quantity Controller decides when it runs again, so it doesn't start next to the unit it chose
      if self.controlMode ~= "disabled" then
        controller:setEnabled(self.isTierActive[tier])
      end
    elseif controller ~= nil and controller.isAdminEnabled == false and self.isAdminDisableLogged[tier] ~= true then
      event.push("log_warning", "[T"..tier.."] Admin disabled until switched on by hand")
      self.isAdminDisableLogged[tier] = true
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
  local reason = nil

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
        reason = self:describeLevel(index, "under "..formatAmount(self.waterThresholds[index]))
        break
      end
    end
  elseif self.controlMode == "singleThreadBalancing" then
    -- The tier with the least water (below its threshold) runs, lower tiers win ties.
    -- A tier below minQty runs first, so higher tiers don't start without enough input
    local winner = nil
    local candidateCount = 0

    for index = 1, 9 do
      if self:isTierUsable(tierOf(index)) and self:isBelowThreshold(index) then
        local isBelowMinQty = self.waterLevels[index] < self.minQty
        candidateCount = candidateCount + 1

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

      if self.waterLevels[winner] < self.minQty then
        reason = self:describeLevel(winner, "under min "..formatAmount(self.minQty))
      elseif candidateCount > 1 then
        reason = self:describeLevel(winner, "lowest stock")
      else
        reason = self:describeLevel(winner, "under "..formatAmount(self.waterThresholds[winner]))
      end
    end
  end

  self.isTierActive = isTierActive
  self:logDecision(isTierActive, reason)

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

---Describe the stock of the fluid at an index of fluidNames, e.g. "G2 7.3M, lowest stock"
---@param index integer
---@param why string
---@return string
---@private
function quantityController:describeLevel(index, why)
  return fluidLabel(index).." "..formatAmount(self.waterLevels[index])..", "..why
end

---Log the units chosen for the next cycle, when they differ from the last choice
---@param isTierActive boolean[]
---@param reason string|nil
---@private
function quantityController:logDecision(isTierActive, reason)
  local tiers = {}

  for tier = 1, 8 do
    if isTierActive[tier] then
      table.insert(tiers, "T"..tier)
    end
  end

  local decision = table.concat(tiers, " ")

  if decision == self.lastDecision then
    return
  end

  self.lastDecision = decision

  if decision == "" then
    event.push("log_info", "[QC] Next cycle: none, "..(self:isNeedBlocked() and "needed units admin disabled" or "all units at threshold"))
  elseif reason ~= nil then
    event.push("log_info", "[QC] Next cycle: "..decision.." ("..reason..")")
  else
    event.push("log_info", "[QC] Next cycle: "..decision)
  end
end

---Check if a fluid is below its threshold, but the unit which makes it is admin disabled
---@return boolean
---@private
function quantityController:isNeedBlocked()
  for index = 1, 9 do
    local controller = self.controllers["t"..tierOf(index)]

    if controller ~= nil and controller.isAdminEnabled == false and self:isBelowThreshold(index) then
      return true
    end
  end

  return false
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
