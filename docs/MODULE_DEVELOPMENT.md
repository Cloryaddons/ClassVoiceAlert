# Developing a ClassVoiceAlert Module

This document describes the standard process for adding a feature module to ClassVoiceAlert.

Author: **Clory**

Before implementing a module, read:

```text
docs/ARCHITECTURE.md
docs/API.md
```

---

## 1. Module naming

Every official feature module uses the physical AddOn namespace:

```text
ClassVoiceAlertToolbox_Module_<ModuleName>
```

Example:

```text
ClassVoiceAlertToolbox_Module_DancingRuneWeapon
```

Do not create new official modules using unrelated physical AddOn names.

---

## 2. Required directory

Example:

```text
addons/
└── ClassVoiceAlertToolbox_Module_Example/
    ├── ClassVoiceAlertToolbox_Module_Example.toc
    ├── ExampleVoiceAlert.lua
    └── README.txt
```

---

## 3. Required TOC

Example:

```toc
## Interface: 120100
## Title: ExampleVoiceAlert
## Notes: Voice alert module for ClassVoiceAlert.
## Author: Clory
## Version: 0.1.0

## Dependencies: ClassVoiceAlertToolbox_Core
## Group: ClassVoiceAlertToolbox

## X-ClassVoiceAlert-Module: true
## X-ClassVoiceAlert-Class: DEATHKNIGHT
## X-ClassVoiceAlert-ModuleID: example
## X-ClassVoiceAlert-ModuleName: 示例提醒

ExampleVoiceAlert.lua
```

Public Blizzard AddOn-list titles must be English.

The toolbox's internal user-facing module name may be Chinese.

---

## 4. Bootstrap

Start module Lua with:

```lua
local ADDON_NAME = ...

local CVA = _G.ClassVoiceAlert
if not CVA or CVA:GetAPIVersion() < 1 then
    return
end
```

Then define stable identifiers:

```lua
local CLASS_ID = "DEATHKNIGHT"
local MODULE_ID = "example"
```

Do not change an established `MODULE_ID` after release without a migration plan.

---

## 5. Database

Define only module-specific defaults:

```lua
local defaults = {
    enabled = true,

    alerts = {
        main = {
            enabled = true,
            warnBefore = 2,

            mode = "blizzard",

            selectedSound = nil,
            selectedCustomSound = nil,
            selectedBlizzardSound = "RAID_WARNING",

            ttsText = "示例提醒",
        },
    },
}
```

Obtain the database through Core:

```lua
local db = CVA:GetModuleDB(
    CLASS_ID,
    MODULE_ID,
    defaults
)
```

Do not create a new SavedVariables database unless preserving legacy configuration requires temporary migration support.

---

## 6. Warning-time range

If the mechanic can exist for at most 10 seconds:

```lua
CVA:NormalizeAlertProfile(db.alerts.main, {
    defaultEnabled = true,

    minWarnBefore = 0,
    maxWarnBefore = 10,
    defaultWarnBefore = 2,

    warnStep = 1,
    defaultText = "示例提醒",
})
```

The maximum value must correspond to the real maximum meaningful lifetime.

Examples:

```text
30-second aura -> 0-30
4-second linger -> 0-4
```

Standard warning time uses integer seconds.

Do not implement custom decimal rounding.

Core already provides:

```lua
CVA:NormalizeWarningSeconds(...)
```

---

## 7. Mechanic implementation

The module should focus on determining:

```text
Should an alert fire now?
```

Preferred sources:

- WoW events;
- secure Blizzard state that is available to AddOns;
- bounded delayed checks;
- Blizzard UI hooks where appropriate.

Avoid permanent polling unless necessary.

Never add:

```lua
while true do
```

Do not introduce a permanent high-frequency `OnUpdate` or ticker when an event-driven implementation is available.

---

## 8. Triggering an alert

Runtime:

```lua
local function FireAlert()
    if not db.enabled then
        return
    end

    if not db.alerts.main.enabled then
        return
    end

    CVA:PlayAlert(db.alerts.main, {
        showError = false,
        defaultText = "示例提醒",
    })
end
```

The module decides when `FireAlert()` is called.

Core decides how the selected sound is played.

---

## 9. Registration

Register after initialization:

```lua
CVA:RegisterModule({
    addon = ADDON_NAME,

    requiredCoreAPI = 1,

    classID = CLASS_ID,
    className = "死亡骑士",

    moduleID = MODULE_ID,
    moduleName = "示例提醒",

    order = 30,

    description = "达到指定条件时进行语音提醒。",
    enabledLabel = "启用示例提醒",

    getDB = function()
        return db
    end,

    alerts = {
        {
            key = "main",

            title = "示例提醒",
            description = "达到条件时进行提醒。",

            showEnabled = true,
            showWarnBefore = true,

            minWarnBefore = 0,
            maxWarnBefore = 10,
            warnStep = 1,

            defaultText = "示例提醒",
        },
    },

    testAlert = function()
        CVA:PlayAlert(db.alerts.main, {
            showError = true,
            defaultText = "示例提醒",
        })
    end,
})
```

---

## 10. Do not duplicate Core systems

A feature module must not implement its own:

```text
LibSharedMedia discovery
TTS voice enumeration
TTS volume
global sound channel
Blizzard SoundKit preset database
custom voice-pack manifest
sound browser
shared alert UI
Blizzard Settings category
slash command
```

If a capability is useful to more than one module, it probably belongs in Core.

---

## 11. Keyboard safety

Feature modules should normally rely entirely on standard Core UI.

If custom UI contains an EditBox:

- disable autofocus;
- clear focus on Escape;
- clear focus before hiding;
- clear focus before disabling;
- clear focus when the parent panel closes.

Use Core keyboard-focus helpers where available.

Never capture normal gameplay keys merely to implement configuration UI.

---

## 12. Parent-child configuration

If the module is disabled:

```text
all child controls must become non-interactive
```

If one alert is disabled:

```text
its enable checkbox remains interactive
its detailed controls become non-interactive
```

Do not delete or reset stored child values when disabling a parent.

---

## 13. User-facing descriptions

Describe what the option does.

Good:

```text
粘滞凋零即将结束且地板还在时，提醒返回凋零地板。
```

Avoid exposing implementation details:

```text
监听 CooldownViewer 188290 的 auraInstance rollover……
```

Debugging details belong in source comments or development documentation.

---

## 14. Public commands

Do not register:

```text
/example
/module
/test
/debug
/status
```

The suite has one public command:

```text
/cvat
```

Testing should be available through the configuration interface when appropriate.

---

## 15. Before committing

Run:

```bash
python scripts/validate.py
```

Then build an installation package:

```bash
python scripts/package.py
```

Install the generated ZIP into WoW and test the actual packaged output.

A module is not considered complete merely because its loose source files load successfully.

---

## 16. Module checklist

Before a module is merged:

- physical AddOn name uses `ClassVoiceAlertToolbox_Module_*`;
- `Author` is `Clory`;
- Blizzard AddOn-list title is English;
- dependency points to `ClassVoiceAlertToolbox_Core`;
- group points to `ClassVoiceAlertToolbox`;
- module uses Core DB;
- module uses `CVA:PlayAlert()`;
- no duplicate LSM/TTS/audio implementation;
- no public slash command;
- no Blizzard Settings registration;
- no unnecessary permanent polling;
- warning range matches the mechanic's real lifetime;
- standard parent-child disabling works;
- keyboard focus remains safe;
- repository validation passes;
- packaged ZIP is tested in game.
