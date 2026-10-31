---@class BaseController
---@field controllerProxy gt_machine
---@field gtSensorParser GtSensorParser
---@field stateMachine? StateMachine
---@field needsAttention boolean
---@field attentionReason string
---@field isWorking boolean Whether the unit ran a recipe when the loop last read it
local baseController = {
  needsAttention = false,
  attentionReason = "",
  isWorking = false
}

---Read whether the unit works, and its sensor information when something uses it. GregTech builds that
---information for every call, and an idle unit in its Idle or Wait End state doesn't read it
function baseController:readState()
  self.isWorking = self.controllerProxy.hasWork() == true

  local state = self.stateMachine ~= nil and self.stateMachine:getCurrentStateKey() or "idle"

  if self.isWorking or (state ~= "idle" and state ~= "waitEnd") then
    self.gtSensorParser:getInformation()
  else
    self.gtSensorParser:clear()
  end
end

---Switch the unit off after a fault. The Quantity Controller won't switch it on again until the player does
---@param reason? string What is wrong, e.g. "Not enough Polyaluminium Chloride for craft"
function baseController:markNeedsAttention(reason)
  self.controllerProxy.setWorkAllowed(false)
  self.needsAttention = true
  self.attentionReason = reason or ""
end

---Clear the fault when the unit was switched on by hand. The program never switches a unit on after a fault, so only the player can have done it
---@return boolean # true if the fault was cleared
function baseController:checkAttentionCleared()
  if self.needsAttention == true and self.controllerProxy.isWorkAllowed() == true then
    self.needsAttention = false
    return true
  end

  return false
end

---Allow or forbid the unit to start a recipe in the next cycle
---@param isEnabled boolean
function baseController:setEnabled(isEnabled)
  self.controllerProxy.setWorkAllowed(isEnabled)
end

return baseController
