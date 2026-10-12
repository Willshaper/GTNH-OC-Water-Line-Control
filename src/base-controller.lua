---@class BaseController
---@field controllerProxy gt_machine
---@field isAdminEnabled boolean
local baseController = {
  isAdminEnabled = true
}

---Disable the unit after a fault. The Quantity Controller won't enable it again until the program restarts
function baseController:adminDisable()
  self.controllerProxy.setWorkAllowed(false)
  self.isAdminEnabled = false
end

---Allow or forbid the unit to start a recipe in the next cycle
---@param isEnabled boolean
function baseController:setEnabled(isEnabled)
  self.controllerProxy.setWorkAllowed(isEnabled)
end

return baseController
