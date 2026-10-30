-- Removes Water Line Control from /home: the files it installed (listed in waterline.files),
-- and asks about config.lua, auto-start and wake on redstone. Other programs in /home are left alone.
local component = require("component")
local filesystem = require("filesystem")

local home = "/home"

---@param question string
---@return boolean
local function ask(question)
  io.write(question.." [y/N] ")
  local answer = io.read()

  return answer ~= nil and answer:lower():sub(1, 1) == "y"
end

---@param path string
---@return string|nil
local function readFile(path)
  local file = io.open(path, "r")

  if not file then
    return nil
  end

  local text = file:read("*a")
  file:close()

  return text
end

local list = readFile(home.."/waterline.files")

if list == nil then
  print("There is no "..home.."/waterline.files, the list of installed files. Nothing was removed.")
  return
end

-- The files, then their folders once they are empty (deepest first)
local folders = {}
local removed = 0

for file in list:gmatch("[^\r\n]+") do
  if file ~= "config.lua" then
    local path = home.."/"..file

    if filesystem.exists(path) and not filesystem.isDirectory(path) then
      filesystem.remove(path)
      removed = removed + 1
    end

    local folder = filesystem.path(path)

    while folder and #folder > #home + 1 do
      folders[folder] = true
      folder = filesystem.path(folder:gsub("/$", ""))
    end
  end
end

local sorted = {}

for folder in pairs(folders) do
  table.insert(sorted, folder)
end

table.sort(sorted, function (a, b) return #a > #b end)

for _, folder in ipairs(sorted) do
  if filesystem.isDirectory(folder) and filesystem.list(folder)() == nil then
    filesystem.remove(folder)
  end
end

filesystem.remove(home.."/waterline.files")
print("Removed "..removed.." files of Water Line Control.")

if filesystem.exists(home.."/config.lua") and ask("Remove config.lua (your settings) too?") then
  filesystem.remove(home.."/config.lua")
  print("Removed config.lua. Backups (config.old*.lua) are kept.")
end

-- The auto-start line in .shrc
local shrc = home.."/.shrc"
local text = readFile(shrc)

if text ~= nil then
  local kept, isRemoved = {}, false

  for line in (text.."\n"):gmatch("(.-)\r?\n") do
    if line:match("^%s*main%s*$") or line:match("^%s*cd /home && main%s*$") then
      isRemoved = true
    else
      table.insert(kept, line)
    end
  end

  if isRemoved then
    while kept[#kept] == "" do
      table.remove(kept)
    end

    local file = assert(io.open(shrc, "w"))
    file:write(table.concat(kept, "\n")..(#kept > 0 and "\n" or ""))
    file:close()
    print("Removed auto-start from "..shrc..".")
  end
end

-- Other programs may rely on wake on redstone, so it is only turned off when asked
for address in component.list("redstone") do
  local isOk, slot = pcall(component.slot, address)

  if isOk and type(slot) == "number" and slot >= 0 then
    local card = component.proxy(address)

    if card.getWakeThreshold() > 0 and ask("Turn off wake on redstone for this computer?") then
      card.setWakeThreshold(0)
      print("Wake on redstone off.")
    end
  end
end
