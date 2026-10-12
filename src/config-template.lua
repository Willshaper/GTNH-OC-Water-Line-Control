local configManager = require("lib.config-manager.index")
local logger = require("lib.oc-logger.index")

local quantityController = require("src.quantity-controller")
local t1controller = require("src.t1-controller")
local t2controller = require("src.t2-controller")
local t3controller = require("src.t3-controller")
local t4controller = require("src.t4-controller")
local t5controller = require("src.t5-controller")
local t6controller = require("src.t6-controller")
local t7controller = require("src.t7-controller")
local t8controller = require("src.t8-controller")

---@class ControllersConfig
---@field t1? T1Controller
---@field t2? T2Controller
---@field t3? T3Controller
---@field t4? T4Controller
---@field t5? T5Controller
---@field t6? T6Controller
---@field t7? T7Controller
---@field t8? T8Controller

---@class Config
---@field enableAutoUpdate boolean
---@field logger Logger
---@field controllers ControllersConfig
---@field quantityController QuantityController

---Check is controller module disabled
---@param value any
---@return boolean
local function isDisabled(value)
  return type(value) == "table" and value.enable == false
end

---Check is quantity control disabled. An unknown mode counts as disabled here, so its own error is the one shown
---@param value any
---@param config table
---@return boolean
local function isQuantityControlDisabled(value, config)
  local activeModes = {multiThread = true, singleThread = true, singleThreadBalancing = true}

  return type(config.quantityController) ~= "table" or activeModes[config.quantityController.controlMode] ~= true
end

---Amount validator for water thresholds
---@return NumberValidator
local function amountValidator()
  return configManager.validators.number:new({
    min = {value = 0}
  })
end

local configTemplate = {
  enableAutoUpdate = configManager.validators.boolean:new(),

  logger = configManager.validators.object:new(
    {
      template = {
        name = configManager.validators.string:new(),
        timeZone = configManager.validators.number:new({
          isInteger = {value = true}
        }),
        handlers = configManager.validators.typedObjectList:new({
          templates = {
            ["discord"] = configManager.validators.object:new(
              {
                template = {
                  logLevel = configManager.validators.enum:new({
                    "debug", "info", "warning", "error"
                  }),
                  messageFormat = configManager.validators.string:new(),
                  discordWebhookUrl = configManager.validators.string:new({
                    isNullable = {value = true}
                  }),
                },
                objectFactory = function (value)
                  return logger.handlers.discord:new(value.logLevel, value.messageFormat, value.discordWebhookUrl)
                end
              }
            ),
            ["file"] = configManager.validators.object:new(
              {
                template = {
                  logLevel = configManager.validators.enum:new({
                    "debug", "info", "warning", "error"
                  }),
                  messageFormat = configManager.validators.string:new(),
                  filePath = configManager.validators.string:new(),
                },
                objectFactory = function (value)
                  return logger.handlers.file:new(value.logLevel, value.messageFormat, value.filePath)
                end
              }
            ),
            ["scrollList"] = configManager.validators.object:new(
              {
                template = {
                  logLevel = configManager.validators.enum:new({
                    "debug", "info", "warning", "error"
                  }),
                  logsListSize = configManager.validators.number:new({
                    min = {value = 16}
                  }),
                },
                objectFactory = function (value)
                  return logger.handlers.scrollList:new(value.logLevel, value.logsListSize)
                end
              }
            ),
          }
        }),
      },
      objectFactory = function (value)
        return logger.logger:new(value.name, value.timeZone, value.handlers)
      end
    }
  ),

  controllers = configManager.validators.object:new({
    template = {
      t1 = configManager.validators.object:new({
        skipper = isDisabled,
        template = {
          enable = configManager.validators.boolean:new(),
        },
        objectFactory = function (value)
          if value.enable == false then
            return nil
          end

          return t1controller:new()
        end
      }),

      t2 = configManager.validators.object:new({
        skipper = isDisabled,
        template = {
          enable = configManager.validators.boolean:new(),
        },
        objectFactory = function (value)
          if value.enable == false then
            return nil
          end

          return t2controller:new()
        end
      }),

      t3 = configManager.validators.object:new({
        skipper = isDisabled,
        template = {
          enable = configManager.validators.boolean:new(),
          transposerAddress = configManager.validators.address:new(),
        },
        objectFactory = function (value)
          if value.enable == false then
            return nil
          end

          return t3controller:new(value.transposerAddress)
        end
      }),

      t4 = configManager.validators.object:new({
        skipper = isDisabled,
        template = {
          enable = configManager.validators.boolean:new(),
          hydrochloricAcidTransposerAddress = configManager.validators.address:new(),
          sodiumHydroxideTransposerAddress = configManager.validators.address:new(),
        },
        objectFactory = function (value)
          if value.enable == false then
            return nil
          end

          return t4controller:new(
            value.hydrochloricAcidTransposerAddress,
            value.sodiumHydroxideTransposerAddress
          )
        end
      }),

      t5 = configManager.validators.object:new({
        skipper = isDisabled,
        template = {
          enable = configManager.validators.boolean:new(),
          plasmaTransposerAddress = configManager.validators.address:new(),
          coolantTransposerAddress = configManager.validators.address:new(),
        },
        objectFactory = function (value)
          if value.enable == false then
            return nil
          end

          return t5controller:new(
            value.plasmaTransposerAddress,
            value.coolantTransposerAddress
          )
        end
      }),

      t6 = configManager.validators.object:new({
        skipper = isDisabled,
        template = {
          enable = configManager.validators.boolean:new(),
          transposerAddress = configManager.validators.address:new(),
        },
        objectFactory = function (value)
          if value.enable == false then
            return nil
          end

          return t6controller:new(value.transposerAddress)
        end
      }),

      t7 = configManager.validators.object:new({
        skipper = isDisabled,
        template = {
          enable = configManager.validators.boolean:new(),
          inertGasTransposerAddress = configManager.validators.address:new(),
          superConductorTransposerAddress = configManager.validators.address:new(),
          netroniumTransposerAddress = configManager.validators.address:new(),
          coolantTransposerAddress = configManager.validators.address:new(),
        },
        objectFactory = function (value)
          if value.enable == false then
            return nil
          end

          return t7controller:new(
            value.inertGasTransposerAddress,
            value.superConductorTransposerAddress,
            value.netroniumTransposerAddress,
            value.coolantTransposerAddress
          )
        end
      }),

      t8 = configManager.validators.object:new({
        skipper = isDisabled,
        template = {
          enable = configManager.validators.boolean:new(),
          maxQuarkCount = configManager.validators.number:new({
            isInteger = {value = true},
            min = {value = 1}
          }),
          transposerAddress = configManager.validators.address:new(),
          subMeInterfaceAddress = configManager.validators.address:new(),
        },
        objectFactory = function (value)
          if value.enable == false then
            return nil
          end

          return t8controller:new(
            value.maxQuarkCount,
            value.transposerAddress,
            value.subMeInterfaceAddress
          )
        end
      }),
    }
  }),

  quantityController = configManager.validators.object:new({
    template = {
      controlMode = configManager.validators.enum:new({
        "disabled", "multiThread", "singleThread", "singleThreadBalancing"
      }),
      meInterfaceAddress = configManager.validators.address:new({
        skipper = isQuantityControlDisabled
      }),
      minQty = amountValidator(),
      waterThresholds = configManager.validators.object:new({
        template = {
          t1 = amountValidator(),
          t2 = amountValidator(),
          t3 = amountValidator(),
          t4 = amountValidator(),
          t5 = amountValidator(),
          t6 = amountValidator(),
          t7 = amountValidator(),
          t8 = amountValidator(),
          stabilisedBaryonicMatter = amountValidator(),
        }
      }),
    },
    objectFactory = function (value)
      local thresholds = value.waterThresholds

      return quantityController:new(
        value.controlMode,
        value.meInterfaceAddress,
        value.minQty,
        {
          thresholds.t1, thresholds.t2, thresholds.t3, thresholds.t4,
          thresholds.t5, thresholds.t6, thresholds.t7, thresholds.t8,
          thresholds.stabilisedBaryonicMatter
        }
      )
    end
  })
}

return configTemplate