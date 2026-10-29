# GTNH-OC-Water-Line-Control (singlethread fork)

This is a fork of the `develop` branch of [Navatusein/GTNH-OC-Water-Line-Control](https://github.com/Navatusein/GTNH-OC-Water-Line-Control/tree/develop).
It adds the **Quantity Controller** from [ehami/gtnh-oc-water-line-control](https://github.com/ehami/gtnh-oc-water-line-control),
which can run the water line single threaded: one Purification Unit per cycle, chosen by how much of each water is in your ME network.

What the fork adds:
- The [Quantity Controller](#quantity-controller) with four modes: `disabled`, `multiThread`, `singleThread` and `singleThreadBalancing`.
- T1 and T2 modules, so the Clarifier and the Ozonation unit can be switched on and off too.
- Units that stop because they ran out of materials stay off ("Admin disabled"), so the Quantity Controller never turns them back on. Switch one back on by hand once it's restocked.
- A coloured screen: each water's stock and threshold, the units the Quantity Controller chose (`▶`), and a countdown to the next cycle.
- The program switches the Water Purification Plant back on when it starts (`enableAutoStart`), so stopping it to edit `config.lua` no longer leaves the plant off.
- The log on the screen shows the time, which units the Quantity Controller chose and why, and when a unit or the plant stops.
- Auto update and the installer use this fork's releases.

> [!CAUTION]
> For GTNH **2.9** and newer only.
> Its `config.lua` has new settings (`t1`, `t2` and `quantityController`), so a config from the original program will not work.

> [!CAUTION]
> The fluid transfer rate of an OpenComputers Transposer depends on the Fluid Regulator it was crafted with in an Assembler.
> Use transposers made with at least an LuV Fluid Regulator. A weaker one moves less fluid per transfer than the program needs.
>
> ![Transposer](/docs/transposer.png)

## Content

- [Information](#information)
- [Installation](#installation)
- [Water Line Setup](#water-line-setup)
- [Quantity Controller](#quantity-controller)
- [Configuration](#configuration)
- [Credits](#credits)

<a id="information"></a>

## Information

Program is designed to automate the water line from T3 to T8 water, and can switch T1 and T2 on and off.
Program is modular, you can choose which water types you want to automate.
The Quantity Controller can also decide which units run, from the amount of each water in your ME network.
It is also possible to send messages to Discord about out of service situations.
And there is also the possibility of auto update at startup.

#### Controls

<kbd>Q</kbd> - Closing the program

<kbd>Arrow Up</kbd> - Scroll list up

<kbd>Arrow Down</kbd> - Scroll list down

#### Interface

![Interface](/docs/interface.png)

The screenshot is of the original program. This fork's screen looks like this, in colour:

```
15:29  Plant ██████░░░░  Next cycle in 37s           Balancing
Unit Stock / Want    State
 T1  32.0M / 32.0M   Idle
▶T2   7.3M / 32.0M   Working 95%
 T3 450.0k / 3.0M    ✗ Admin disabled
 T4      0 / 64.0k   Unused
...
 BM      0 / 64.0k
────────────────────────────────────────
|15:29 [QC] Next cycle: T2 (G2 7.3M, under min 8.0M)
|15:29 [Line] Water Purification Plant switched on
↑↓ scroll   Q quit   ▶ next cycle   ✗ admin disabled
```

- The header shows the time, the cycle as a bar, the time to the next cycle (or "Plant stopped" in red) and the control mode.
- Stock is red under `minQty`, yellow under its threshold and green at or above it.
- `▶` marks the units the Quantity Controller chose for the next cycle.
- State: "Working" with the success chance, "Waiting" (switched on, waiting for the next cycle), "Idle" (switched off by the Quantity Controller or by hand), "✗ Admin disabled" (stopped after a fault, see below) or "Unused" (not enabled in `config.lua`).

<a id="installation"></a>

## Installation

> [!CAUTION]
> On Java 8 the download from GitHub can fail, because Java rejects GitHub's certificates.
> Then the only way to install the program is to copy its files to the computer by hand.

To install program, you need a server with:
- Graphics Card (Tier 3): 1
- Central Processing Unit (CPU) (Tier 3): 1
- Memory (Tier 3.5): 2
- Component Bus (Tier 3): 1
- Hard Disk Drive (Tier 3) (4MB): 1
- EEPROM (Lua BIOS): 1
- Internet Card: 1

![Computer setup](/docs/server.png)

Install the basic Open OS on your computer.
Then run this command to install the fork. It downloads the latest release into `/home`.
An existing `config.lua` is kept as `config.old.lua` (or `config.old2.lua` and so on, if that exists).

```shell
wget -f https://raw.githubusercontent.com/Willshaper/GTNH-OC-Water-Line-Control/develop/setup.lua && setup
```

The installer of the original program (`pastebin run ESUAMAGx`) installs the original, without the Quantity Controller.

To start the program, run:

```shell
main
```

To start it whenever the computer boots, add it to `/home/.shrc`:

```shell
echo main >> /home/.shrc
```

> [!NOTE]  
> For convenient configuration you can use the web configurator.
> [GTNH-OC-Web-Configurator](https://navatusein.github.io/GTNH-OC-Web-Configurator/#/configurator?url=https%3A%2F%2Fraw.githubusercontent.com%2FWillshaper%2FGTNH-OC-Water-Line-Control%2Frefs%2Fheads%2Fdevelop%2Fconfig-descriptor.yml)

#### Computer setup

The program interface is configured for a 3x2 monitor.

![Computer setup](/docs/computer-setup.png)

<a id="water-line-setup"></a>

## Water Line Setup

> [!NOTE]  
> For easy copying of addresses, use "Analyzer" from the OpenComputers mod. Right-click on the component, its address will be written in the chat. 
> If you click on it, it will be copied.
>
> <img src="docs/analyzer.png" alt="Analyzer" width="120"/>

### Water Purification Plant

#### Components

To build a setup, you will need:
- Adapter: 1
- MFU: 1

#### Description

The main multiblock of the line. The cycle of the entire line is read from it.

> [!CAUTION]
> Water Purification Plant must be connected.

The controller is connected via MFU to keep it accessible.

#### Example setup

![Water Purification Plant](/docs/water-purification-plant.png)

<a id="t1-t2"></a>

### [T1] Filtered Water (Grade 1) and [T2] Ozonated Water (Grade 2)

#### Components

To build a setup, you will need for each of them:
- Adapter: 1
- MFU: 1

#### Description

These modules only switch the unit on and off, so the Quantity Controller can choose them.
They don't supply anything: keep the Clarifier stocked with Activated Carbon Filter Mesh and the Ozonation unit with Ozone yourself.
Enable them with `enable = true` in the `config.lua`. You only need them when you use the Quantity Controller.

The controllers are connected via MFU, like the Water Purification Plant.

> [!CAUTION]
> The Ozonation unit explodes if its input hatch holds more than 1,024,000 L of Ozone.

#### T1 and T2 Config part

```Lua
t1 = { -- Controller for T1 Filtered Water (Grade 1)
  enable = false -- Enable module for T1 water
},

t2 = { -- Controller for T2 Ozonated Water (Grade 2)
  enable = false -- Enable module for T2 water
},
```

### [T3] Flocculated Water (Grade 3)

> [!CAUTION]
> Use transposers made with at least an LuV Fluid Regulator.

#### Components

To build a setup, you will need:
- Adapter: 1
- Transposer: 1
- MFU: 1

#### Description

To use the module for t3 water in the `config.lua`
file you need to enable the module by changing `enable = false` to `enable = true`. 
You must also specify the address of the transposer in the `transposerAddress` field, which is located under the ZPM input hatch and to which the tank with the 
Polyaluminium chloride connected.

The controller is connected via MFU to keep it accessible.

#### T3 Config part

```Lua
t3 = { -- Controller for T3 Flocculated Water (Grade 3)
  enable = false, -- Enable module for T3 water
  transposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Polyaluminium Chloride
},
```

#### Example setup

![T3 Setup](/docs/t3-setup.png)

### [T4] pH Neutralized Water (Grade 4)

> [!CAUTION]
> Use transposers made with at least an LuV Fluid Regulator.

#### Components

To build a setup, you will need:
- Adapter: 1
- Transposer: 2

#### Description

To use the module for t4 water in the `config.lua`
file you need to enable the module by changing `enable = false` to `enable = true`. 
It is also necessary to specify transposer addresses in 
the fields `hydrochloricAcidTransposerAddress` and `sodiumHydroxideTransposerAddress`, 
they are respectively located above the input hatch for Hydrochloric Acid next to the 
tank and above the input bus for Sodium Hydroxide next to the interface.

#### T4 Config part

```Lua
t4 = { -- Controller for T4 pH Neutralized Water (Grade 4)
  enable = false, -- Enable module for T4 water
  hydrochloricAcidTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Hydrochloric Acid
  sodiumHydroxideTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Sodium Hydroxide Dust
},
```

#### Example setup

![T4 Setup](/docs/t4-setup.png)

### [T5] Extreme-Temperature Treated Water (Grade 5)

> [!CAUTION]
> Use transposers made with at least an LuV Fluid Regulator.

#### Components

To build a setup, you will need:
- Adapter: 1
- Transposer: 2

#### Description

To use the module for t5 water in the `config.lua`
file you need to enable the module by changing `enable = false` to `enable = true`. 
It is also necessary to specify transposer addresses in 
the fields `plasmaTransposerAddress` and `coolantTransposerAddress`, 
they are respectively located below the input hatch for Helium Plasma next to the 
tank and below the input hatch for Super Coolant next to the tank.

#### T5 Config part

```Lua
t5 = { -- Controller for T5 Extreme-Temperature Treated Water (Grade 5)
  enable = false, -- Enable module for T5 water
  plasmaTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Helium Plasma
  coolantTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Super Coolant
},
```

#### Example setup

![T5 Setup](/docs/t5-setup.png)

### [T6] Ultraviolet Treated Electrically Neutral Water (Grade 6)

#### Components

To build a setup, you will need:
- Adapter: 1
- Transposer: 1

#### Description

To use the module for t6 water in the `config.lua`
file you need to enable the module by changing `enable = false` to `enable = true`. 
You must also specify the address of the transposer in the `transposerAddress` field, which is located above the Lens Housing and to which the chest with lenses connected.

The chest should contain all 9 lenses: Orundum Lens, Amber Lens, Aer Lens, Emerald Lens, Mana Diamond Lens, Blue Topaz Lens, Amethyst Lens, Fluor-Buergerite Lens, Dilithium Lens.

> [!NOTE]  
> Dilithium Lens is optional.

![Chest With Lenses](/docs/chest-with-lenses.png)

#### T6 Config part

```Lua
t6 = { -- Controller for T6 Ultraviolet Treated Electrically Neutral Water (Grade 6)
  enable = false, -- Enable module for T6 water
  transposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Lenses
},
```

#### Example setup

![T6 Setup](/docs/t6-setup.png)

### [T7] Degassed Decontaminant-Free Water (Grade 7)

> [!CAUTION]
> Use transposers made with at least an LuV Fluid Regulator.

#### Components

To build a setup, you will need:
- Adapter: 1
- Transposer: 4
- MFU: 1

#### Description

> [!NOTE]  
> The structure needs a `Degasser Control Hatch` to form. The program doesn't use it: it reads the control signal from the controller.

To use the module for t7 water in the `config.lua`
file you need to enable the module by changing `enable = false` to `enable = true`.
You must also specify the addresses of the transposers: 
`inertGasTransposerAddress` here is the address of the transposer that will supply Helium, Neon, Krypton, Xenon.
`superConductorTransposerAddress` here is the address of the transposer that will supply Superconductor Base.
`netroniumTransposerAddress` here is the address of the transposer that will supply Molten Neutronium.
`coolantTransposerAddress` here is the address of the transposer that will supply Super Coolant.

The controller is connected via MFU to keep it accessible.

#### T7 Config part

```Lua
t7 = { -- Controller for T7 Degassed Decontaminant-Free Water (Grade 7)
  enable = false, -- Enable module for T7 water
  inertGasTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Inert Gas
  superConductorTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Super Conductor
  netroniumTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Molten Neutronium
  coolantTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of transposer which provide Super Coolant
},
```

#### Example setup

![T7 Setup](/docs/t7-setup.png)

### [T8] Subatomically Perfect Water (Grade 8)

#### Components

To build a setup, you will need:
- Adapter: 2
- Transposer: 1
- MFU: 1

#### Description

To use the module for t8 water in the `config.lua`
file you need to enable the module by changing `enable = false` to `enable = true`.
You must also specify the address of the transposer in the `transposerAddress` 
field, which is located under the hv input bus and to which the interface with the Quarks connected.
Also the address of the adapter connected to me interface in the `subMeInterfaceAddress` field.
Also in the configs you can change the number of quarks the computer must support in this field ` maxQuarkCount`.
There you need to specify the number of quarks that are in the subnet. So if you put 7 quarks of each type in the subnet. 
3 will go into the interface, then you need to specify 4. Because that's how many are left in the subnet.

The controller is connected via MFU to keep it accessible.

The idea is that a separate subnet is made for quarks. The Absolute Baryonic Perfection Purification Unit returns unused quarks and 2 
Unaligned Quark Releasing Catalysts after crafting is complete. The computer looks to see which quarks are less than the specified 
number (`maxQuarkCount` in the default configs is 4) and orders them. That is, the subnet must have at least 2 CPUs and a 
Hyper-Intensity Laser Engraver connected to order quarks. It is possible without a subnet, but the condition is that the computer can order quarks. 
Stabilised Baryonic Matter can be fed into the subsystem or directly into the Laser Engraver.

> [!NOTE]  
> Maximum 42 infinity ingots used per cycle. But usually less. Consumption can be 6, 18, 42 ingots per cycle. Depends on luck.

#### T8 Config part

```Lua
t8 = { -- Controller for T8 Subatomically Perfect Water (Grade 8)
  enable = false, -- Enable module for T8 water
  maxQuarkCount = 4, -- Maximum number of each quark in the sub AE
  transposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of transposer which provide Quarks
  subMeInterfaceAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" -- Address of me interface which connected to sub AE
}
```

#### Example setup

![T8 Setup 1](/docs/t8-setup-1.png)

![T8 Setup 2](/docs/t8-setup-2.png)

<a id="quantity-controller"></a>

## Quantity Controller

The Quantity Controller reads how much of each water, and of Stabilised Baryonic Matter, is in your ME network.
About 10 seconds before each cycle of the Water Purification Plant ends, it chooses which units may start in the next cycle,
and turns every other unit off. A unit that is turned off still finishes the cycle it is running.

Single threaded, each unit can get enough parallels to use all the power of the Water Purification Plant.
Parallels are set in each unit's GUI. GregTech caps the water a unit makes at 2,147,483,647 L per cycle, so more than about 2.39 million parallels gain nothing.
Catalysts (Polyaluminium Chloride, Ozone, plasma, Super Coolant, quark catalysts, Molten Infinity and so on) don't scale with parallels,
so fewer cycles with more parallels use less of them. See [Singlethreaded Waterline](https://wiki.gtnewhorizons.com/wiki/Water_Line#Singlethreaded_Waterline) on the wiki.

#### Components

- Adapter: 1, next to an ME Interface on the network which stores the water
- Adapters with MFUs for the T1 and T2 controllers, see [T1 and T2](#t1-t2)

Only units with an enabled module (`enable = true`) are controlled.
In the single thread modes, every unit of the line needs its module, or the units without one keep running on their own.

#### Modes

- `"disabled"` - No quantity control. Every enabled unit runs every cycle, like the original program.
- `"multiThread"` - Every tier below its threshold runs.
- `"singleThread"` - The lowest tier below its threshold runs. This is how the wiki's singlethreaded waterline works.
- `"singleThreadBalancing"` - The tier with the least water (of those below their threshold) runs, a lower tier wins a tie.
  A tier below `minQty` always runs first, so a higher tier doesn't start without enough input.
  Set `minQty` to the most water one cycle uses: your highest parallel count × 1000.
  Keep every threshold above `minQty`: a tier at or above its threshold doesn't run, even when it has less than `minQty`.

T8 also runs when Stabilised Baryonic Matter is below its threshold. T8 makes it, and it's needed to realign quark catalysts.

A unit that ran out of materials is shown as "Admin disabled", and the Quantity Controller doesn't enable it again.
Once it's restocked, switch the unit back on by hand (soft mallet, or the button in its GUI): the program then uses it again.
In the multi and single thread modes the program switches it off again within a few seconds and keeps it off until it chooses that unit.
Switched on in the last few seconds of a cycle, it can start once next to the unit the Quantity Controller chose.

#### Quantity Controller Config part

```Lua
quantityController = { -- Decides which units run, from the amount of each water in the ME network
  controlMode = "disabled", -- "disabled", "multiThread", "singleThread" or "singleThreadBalancing"
  meInterfaceAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- Address of me interface on the network which stores the water
  minQty = 32000, -- Tiers with less water than this run first (singleThreadBalancing). Set it to the most water one cycle uses: max parallels * 1000, and keep every threshold above it
  waterThresholds = { -- Amount to keep stocked, in L
    t1 = 64000,
    t2 = 64000,
    t3 = 64000,
    t4 = 64000,
    t5 = 64000,
    t6 = 64000,
    t7 = 64000,
    t8 = 64000,
    stabilisedBaryonicMatter = 64000 -- Made by T8, needed to realign quark catalysts
  }
}
```

> [!NOTE]
> A unit's output only reaches the ME network when its cycle ends, after the next cycle is already chosen.
> So the tier that just ran is often chosen once more before the new water counts.

<a id="configuration"></a>

## Configuration

> [!NOTE]  
> For convenient configuration you can use the web configurator.
> [GTNH-OC-Web-Configurator](https://navatusein.github.io/GTNH-OC-Web-Configurator/#/configurator?url=https%3A%2F%2Fraw.githubusercontent.com%2FWillshaper%2FGTNH-OC-Water-Line-Control%2Frefs%2Fheads%2Fdevelop%2Fconfig-descriptor.yml)

General configuration in file `config.lua`
The configuration of water line modules is described in paragraph [Water Line Setup](#water-line-setup),
and the `quantityController` settings in [Quantity Controller](#quantity-controller).

Enable auto update when starting the program.

```lua
enableAutoUpdate = true, -- Enable auto update on start
```

The program switches the Water Purification Plant off whenever it stops, for example when you stop it to edit `config.lua` or when it crashes.
The plant still finishes the cycle it is running, but doesn't start a new one.
With `enableAutoStart` the program switches the plant back on when it starts. Set it to `false` to switch the plant on by hand.
A `config.lua` without this line counts as `true`.

```lua
enableAutoStart = true, -- Switch the Water Purification Plant on when the program starts. Stopping the program switches it off
```

In the `timeZone` field you can specify your time zone.

In the `discordWebhookUrl` field, you can specify the Discord Webhook link so that the program sends messages to the discord about emergency situations.
[How to Create a Discord Webhook?](https://www.svix.com/resources/guides/how-to-make-webhook-discord/)

```lua
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
```

The log on the screen (`scrollList`) shows the time and what the program does, newest on top. Scroll it with the arrow keys.
- `[QC] Next cycle: T2 (G2 7.3M, lowest stock)` - the units the Quantity Controller chose, each time the choice changes, and why.
- `[T3] Admin disabled until switched on by hand` and `[T3] Enabled by hand, no longer admin disabled`.
- `[Line] Plant stopped (switched off or no power)` and `[Line] Water Purification Plant switched on`.
- `[Line] Cycle started: T2` - the units running in each new cycle. This is a `debug` line, set `logLevel = "info"` to keep it off the screen.

The same line again doesn't add a new row, the newest row gets a count instead, e.g. `[Line] Cycle started: T2 (x4)`. `logs.log` keeps every line.
A `scrollList` without `messageFormat` uses `"{Time:%H:%M} {Message}"`.

<a id="credits"></a>

## Credits

- [Navatusein](https://github.com/Navatusein) wrote Water Line Control.
- [ehami](https://github.com/ehami) wrote the Quantity Controller, the T1 and T2 modules and the Admin disabled state, ported here to the 2.9 version.
