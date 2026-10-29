local config = {
  enableAutoUpdate = true, -- Enable auto update on start
  enableAutoStart = true, -- Switch the Water Purification Plant on when the program starts. Stopping the program switches it off

  logger = {
    name = "Water Line Control",
    timeZone = 3, -- Your time zone
    handlers = {
      ["discord"] = {
        type = "discord",
        logLevel = "warning",
        messageFormat = "{Time:%d.%m.%Y %H:%M:%S} [{LogLevel}]: {Message}",
        discordWebhookUrl = "" -- Discord Webhook URL
      },
      ["file"] = {
        type = "file",
        logLevel = "debug",
        messageFormat = "{Time:%d.%m.%Y %H:%M:%S} [{LogLevel}]: {Message}",
        filePath = "logs.log"
      },
      ["scrollList"] = {
        type = "scrollList",
        logLevel = "debug",
        messageFormat = "{Time:%H:%M} {Message}",
        logsListSize = 32
      },
    }
  },

  controllers = {
    t1 = { -- Controller for T1 Filtered Water (Grade 1)
      enable = false -- Enable module for T1 water
    },

    t2 = { -- Controller for T2 Ozonated Water (Grade 2)
      enable = false -- Enable module for T2 water
    },

    t3 = { -- Controller for T3 Flocculated Water (Grade 3)
      enable = false, -- Enable module for T3 water
      transposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Polyaluminium Chloride
    },

    t4 = { -- Controller for T4 pH Neutralized Water (Grade 4)
      enable = false, -- Enable module for T4 water
      hydrochloricAcidTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Hydrochloric Acid
      sodiumHydroxideTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Sodium Hydroxide Dust
    },

    t5 = { -- Controller for T5 Extreme-Temperature Treated Water (Grade 5)
      enable = false, -- Enable module for T5 water
      plasmaTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Helium Plasma
      coolantTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Super Coolant
    },

    t6 = { -- Controller for T6 Ultraviolet Treated Electrically Neutral Water (Grade 6)
      enable = false, -- Enable module for T6 water
      transposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Lenses
    },

    t7 = { -- Controller for T7 Degassed Decontaminant-Free Water (Grade 7)
      enable = false, -- Enable module for T7 water
      inertGasTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Inert Gas
      superConductorTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Super Conductor
      netroniumTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Molten Neutronium
      coolantTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Super Coolant
    },

    t8 = { -- Controller for T8 Subatomically Perfect Water (Grade 8)
      enable = false, -- Enable module for T8 water
      maxQuarkCount = 4, -- Maximum number of each quark in the sub AE
      transposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Quarks
      subMeInterfaceAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of me interface which connected to sub AE
    }
  },

  quantityController = { -- Decides which units run, from the amount of each water in the ME network
    controlMode = "disabled", -- "disabled", "multiThread", "singleThread" or "singleThreadBalancing"
    meInterfaceAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of me interface on the network which stores the water

    -- singleThreadBalancing picks one unit each cycle, in this order:
    -- 1. A water under floorQty: the lowest tier runs
    -- 2. A water under minQty: the lowest tier runs
    -- 3. Otherwise the water with the least stock (under its threshold) runs
    floorQty = 1000000, -- Every water is filled to this first (singleThreadBalancing)
    minQty = 8000000, -- Then every water is filled to this (singleThreadBalancing). At least one cycle's input (parallels * 1000), more builds a reserve
    waterThresholds = { -- Amount to keep stocked, in L. 0: no cap, the water keeps being made
      t1 = 32000000,
      t2 = 32000000,
      t3 = 32000000,
      t4 = 32000000,
      t5 = 32000000,
      t6 = 32000000,
      t7 = 32000000,
      t8 = 32000000,
      stabilisedBaryonicMatter = 32000000 -- Made by T8, needed to realign quark catalysts
    }
  }
}

return config