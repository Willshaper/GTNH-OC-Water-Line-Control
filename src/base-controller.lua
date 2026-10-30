---@class BaseController
---@field controllerProxy gt_machine
---@field needsAttention boolean
---@field attentionReason string
local baseController = {
  needsAttention = false,
  attentionReason = ""
}

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
