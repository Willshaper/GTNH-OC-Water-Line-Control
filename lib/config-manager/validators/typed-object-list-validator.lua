local classBuilder = require("lib.class-builder.index")

local helper = require("lib.config-manager.helpers.helper")

---@class TypedObjectListValidatorOptions: BaseConfigValidatorOptions
---@field templates table<string, ObjectValidator>

---@class TypedObjectListValidator: BaseConfigValidator
---@field templates table<string, ObjectValidator>
local typedObjectListValidator = {}

---Constructor
---@param options TypedObjectListValidatorOptions
---@return TypedObjectListValidator
function typedObjectListValidator:constructor(options)
  self.templates = options.templates
  self.skipper = options.skipper
  self.isNullable = options.isNullable or false
  self.checker = options.checker

  return self
end

---Validate
---@param value any
---@param config table<string, any>
---@return boolean isValid
---@return string? message
function typedObjectListValidator:validate(value, config)
  if self.skipper ~= nil and self.skipper(value, config) == true then
    return true, nil
  end

  if self.isNullable == true and type(value) == "nil" then
    return true, nil
  end

  if type(value) ~= "table" then
    return false, "invalid type expected: table"
  end

  if self.checker ~= nil and self.checker.value(value, config) == false then
    return false, self.checker.message or "didn't pass the checker"
  end

  -- pairs, not ipairs: the objects are usually keyed by name, like ["file"]
  for objectKey, object in pairs(value) do
    if type(object) ~= "table" then
      return false, "("..tostring(objectKey)..") invalid type expected: table"
    end

    if object.type ~= nil and self.templates[object.type] ~= nil then
      local isValid, message = self.templates[object.type]:validate(object, config)

      if isValid == false then
        return false, "("..tostring(objectKey)..") "..message
      end
    else
      local names = {}

      for name in pairs(self.templates) do
        table.insert(names, '"'..name..'"')
      end

      table.sort(names)

      return false, "("..tostring(objectKey)..") unknown type: "..tostring(object.type)..", use one of: "..table.concat(names, ", ")
    end
  end

  return true, nil
end

---Factory
---@param value table
---@return table
function typedObjectListValidator:factory(value)
  local buildedConfig = {}

  for objectKey, object in pairs(value) do
    buildedConfig[objectKey] = self.templates[object.type]:factory(object)
  end

  return buildedConfig
end


return classBuilder.createClass(typedObjectListValidator, typedObjectListValidator.constructor, "TypedObjectListValidator")