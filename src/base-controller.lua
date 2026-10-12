---@class BaseController
---@field controllerProxy gt_machine
---@field isAdminEnabled boolean
local baseController = {
  isAdminEnabled = true
}

---Disable the unit after a fault. The Quantity Controller won't enable it again until it's enabled by hand
function baseController:adminDisable()
  self.controllerProxy.setWorkAllowed(false)
  self.isAdminEnabled = false
end

---Clear the fault when the unit was enabled by hand. The program never enables a unit after a fault, so only the player can have done it
---@return boolean # true if the fault was cleared
function baseController:checkAdminReset()
  if self.isAdminEnabled == false and self.controllerProxy.isWorkAllowed() == true then
    self.isAdminEnabled = true
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
