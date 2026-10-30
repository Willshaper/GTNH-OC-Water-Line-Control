local event = require("event")

---Event listeners of the controllers. OpenOS keeps a program's listeners after it ends,
---so they are all cancelled when the program stops or starts again after an error
local listeners = {}

---@type number[]
local ids = {}

---Listen to an event. An error in the callback is pushed as "program_error", so the program starts again
---@param name string
---@param callback function
---@return number|boolean id
function listeners.listen(name, callback)
  local id = event.listen(name, function (...)
    local isOk, problem = xpcall(callback, debug.traceback, ...)

    if not isOk then
      event.push("program_error", problem)
    end
  end)

  if id then
    table.insert(ids, id)
  end

  return id
end

---Cancel every listener
function listeners.cancelAll()
  for _, id in ipairs(ids) do
    event.cancel(id)
  end

  ids = {}
end

return listeners
