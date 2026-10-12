-- Installs the latest release of this fork into /home
--   wget -f https://raw.githubusercontent.com/Willshaper/GTNH-OC-Water-Line-Control/develop/setup.lua && setup
local shell = require("shell")
local filesystem = require("filesystem")
local component = require("component")
local internet = require("internet")

local repository = "Willshaper/GTNH-OC-Water-Line-Control"
local branch = "develop"
local archiveName = "WaterLineControl"

local tarManUrl = "https://raw.githubusercontent.com/Navatusein/GTNH-OC-Installer/refs/heads/main/tar/tar.man"
local tarBinUrl = "https://raw.githubusercontent.com/Navatusein/GTNH-OC-Installer/refs/heads/main/tar/tar.lua"

---Get the version.lua of the branch
---@return table|nil
local function getLatestVersion()
  local success, request = pcall(internet.request, "https://raw.githubusercontent.com/"..repository.."/refs/heads/"..branch.."/version.lua")

  if not success or not request then
    return nil
  end

  local result = ""

  local readSuccess = pcall(function ()
    for chunk in request do
      result = result..chunk
    end
  end)

  if not readSuccess then
    return nil
  end

  local loader = load(result)

  if loader == nil then
    return nil
  end

  local loadSuccess, version = pcall(loader)

  if not loadSuccess or type(version) ~= "table" then
    return nil
  end

  return version
end

if not component.isAvailable("internet") then
  io.stderr:write("This computer needs an internet card.\n")
  return
end

local version = getLatestVersion()

if version == nil then
  io.stderr:write("Could not read the latest version from GitHub.\n")
  return
end

print("Installing Water Line Control (singlethread fork) "..version.programVersion)

if not filesystem.exists("/bin/tar.lua") then
  shell.setWorkingDirectory("/usr/man")
  shell.execute("wget -fq "..tarManUrl)
  shell.setWorkingDirectory("/bin")
  shell.execute("wget -fq "..tarBinUrl)
end

shell.setWorkingDirectory("/home")

local url = "https://github.com/"..repository.."/releases/download/v"..version.programVersion.."/"..archiveName..".tar"

shell.execute("wget -fq "..url.." program.tar")

if not filesystem.exists("/home/program.tar") or filesystem.size("/home/program.tar") == 0 then
  filesystem.remove("/home/program.tar")
  io.stderr:write("Could not download "..url.."\n")
  return
end

-- Keep earlier backups too: config.old.lua, then config.old2.lua, ...
if filesystem.exists("/home/config.lua") then
  local backup = "config.old.lua"
  local number = 1

  while filesystem.exists("/home/"..backup) do
    number = number + 1
    backup = "config.old"..number..".lua"
  end

  filesystem.rename("/home/config.lua", "/home/"..backup)
  print("Your config.lua is now "..backup..". Copy your settings into the new config.lua.")
end

shell.execute("tar -xf program.tar")
filesystem.remove("/home/program.tar")

print("Installed. Edit the settings with: edit config.lua")
print("Start with: main")
