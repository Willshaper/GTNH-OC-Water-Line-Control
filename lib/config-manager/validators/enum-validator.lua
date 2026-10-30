local classBuilder = require("lib.class-builder.index")

---@class EnumValidatorOptions: BaseConfigValidatorOptions

---@class EnumValidator: BaseConfigValidator
---@field values table<string>
local enumValidator = {}

---Constructor
---@param values table<string>
---@param options? EnumValidatorOptions
---@return EnumValidator
function enumValidator:constructor(values, options)
  options = options or {}

  self.values = values
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
function enumValidator:validate(value, config)
  if self.skipper ~= nil and self.skipper(value, config) == true then
    return true, nil
  end

  if self.isNullable == true and type(value) == "nil" then
    return true, nil
  end

  if type(value) ~= "string" then
    return false, "invalid type expected: string"
  end

  if self.checker ~= nil and self.checker.value(value, config) == false then
    return false, self.checker.message or ("didn't pass the checker")
  end

  -- Any case is accepted: "SingleThreadBalancing" is "singleThreadBalancing"
  for _, enumValue in pairs(self.values) do
    if value:lower() == enumValue:lower() then
      return true, nil
    end
  end

  local names = {}

  for _, enumValue in pairs(self.values) do
    table.insert(names, '"'..enumValue..'"')
  end

  return false, "invalid value: \""..value.."\", use one of: "..table.concat(names, ", ")
end

---Factory
---@param value string
---@return string
function enumValidator:factory(value)
  -- The value as listed, whatever case it was written in
  if type(value) == "string" then
    for _, enumValue in pairs(self.values) do
      if value:lower() == enumValue:lower() then
        return enumValue
      end
    end
  end

  return value
end

return classBuilder.createClass(enumValidator, enumValidator.constructor, "EnumValidator")