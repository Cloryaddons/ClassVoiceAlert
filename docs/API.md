# ClassVoiceAlert Core API

**Runtime API version:** `1`  
**Document revision:** `1.0`  
**Root AddOn:** `ClassVoiceAlertToolbox`  
**Core AddOn:** `ClassVoiceAlertToolbox_Core`

This is the compatibility contract for feature modules.

## Bootstrap

```lua
local ADDON_NAME = ...
local CVA = _G.ClassVoiceAlert
if not CVA or CVA:GetAPIVersion() < 1 then return end
```

Public identity:

```lua
CVA.VERSION      -- Suite/Core display version, currently synchronized with VERSION
CVA.API_VERSION  -- runtime compatibility integer
CVA:GetAPIVersion()
```

## Database

```lua
CVA:GetDB()
CVA:GetGlobalDB()
CVA:GetModuleDB(classID, moduleID, defaults)
CVA:CopyDefaults(target, defaults)
CVA:ClampNumber(value, minValue, maxValue, fallback)
CVA:NormalizeWarningSeconds(value, minValue, maxValue, fallback)
CVA:NormalizeAlertProfile(profile, spec)
```

Legacy migration helpers:

```lua
CVA:OfferLegacyGlobalSettings(sourceName, priority, legacy)
CVA:FinalizeLegacyGlobalMigration()
```

Core owns:

```lua
ClassVoiceAlertDB = {
    schemaVersion = 1,
    global = {
        soundChannel = "Master",
        ttsVoiceID = nil,
        ttsVolume = 100,
    },
    modules = {
        [classID] = {
            [moduleID] = {...},
        },
    },
    migrations = {...},
}
```

New feature modules should use `CVA:GetModuleDB()` instead of creating new SavedVariables. Legacy SavedVariables may remain temporarily only for migration compatibility.

## Standard alert profile

Core supports the common profile shape:

```lua
{
    enabled = true,
    warnBefore = 5,
    mode = "blizzard", -- custom | lsm | blizzard | tts
    selectedSound = nil,
    selectedCustomSound = nil,
    selectedBlizzardSound = "RAID_WARNING",
    ttsText = "提醒文本",
}
```

Normalize it with:

```lua
CVA:NormalizeAlertProfile(profile, {
    defaultEnabled = true,
    minWarnBefore = 0,
    maxWarnBefore = 30,
    defaultWarnBefore = 5,
    warnStep = 1,
    defaultText = "提醒文本",
})
```

`warnBefore` is stored as an integer. Fractional manual input uses `math.ceil()` and is then clamped to the declared range.

## Playback

Every runtime/test alert must use:

```lua
CVA:PlayAlert(profile, {
    showError = false,
    defaultText = "提醒文本",
})
```

Tests normally use `showError = true`.

Feature modules must not call TTS, `PlaySound`, `PlaySoundFile`, or LSM directly.

## Media discovery

Core-owned APIs:

```lua
CVA:GetLSM()
CVA:GetLSMSounds()
CVA:FetchLSMSound(name)

CVA:GetCustomSoundProvider()
CVA:GetCustomSounds()
CVA:GetCustomSoundEntry(name)

CVA:GetBlizzardSounds()
CVA:GetBlizzardSoundEntry(key)

CVA:GetTTSVoices()
CVA:GetTTSVoice()

CVA:GetAlertSoundLabel(profile)
CVA:GetAlertSourceStatus(profile)
CVA:PlayDefaultWarning()
```

LSM invariant: only a successful `LibSharedMedia-3.0` lookup may be cached. Never cache nil/failure.

## Module registration

Register a module once:

```lua
CVA:RegisterModule({
    addon = ADDON_NAME,
    requiredCoreAPI = 1,

    classID = "DEATHKNIGHT",
    className = "死亡骑士",

    moduleID = "example",
    moduleName = "示例提醒",
    order = 30,
    description = "用户可读的功能说明。",
    enabledLabel = "启用示例提醒",

    getDB = function() return db end,

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

Registry/navigation APIs:

```lua
CVA:GetModule(classID, moduleID)
CVA:RefreshNavigation()
CVA:ShowGlobalSettings()
CVA:ShowModule(classID, moduleID)
CVA:SelectClass(classID)
CVA:Open()
CVA:OpenModule(classID, moduleID)
```

Feature modules normally only need `CVA:RegisterModule()`.

## Standard UI

```lua
CVA.UI:BuildStandardModulePanel(parent, descriptor)
CVA.UI:BuildGlobalPanel(parent)
CVA.UI:ClearKeyboardFocus(rootFrame)
CVA:OpenSoundBrowser(profile, source, onChanged)
```

Prefer the standard module panel. A custom panel is allowed only for genuinely nonstandard interaction and must preserve:
- parent -> child enable hierarchy;
- keyboard-focus safety;
- shared global audio settings;
- Core-owned playback/media logic.

## TOC contract

Feature AddOn folder/TOC naming:

```text
ClassVoiceAlertToolbox_Module_<ShortModuleName>/
    ClassVoiceAlertToolbox_Module_<ShortModuleName>.toc
```

Required TOC metadata:

```toc
## Title: <English AddOns-list name>
## Author: Clory
## Dependencies: ClassVoiceAlertToolbox_Core
## Group: ClassVoiceAlertToolbox
## X-ClassVoiceAlert-Module: true
## X-ClassVoiceAlert-Class: <CLASS_ID>
## X-ClassVoiceAlert-ModuleID: <module_id>
## X-ClassVoiceAlert-ModuleName: <localized name>
```

Do not register module-local slash commands or Blizzard Settings categories.

## Mandatory development invariants

1. No duplicate LSM/TTS/custom-provider/Blizzard-sound implementation in feature modules.
2. No class mechanic or spell ID in Core.
3. Runtime alerts use `CVA:PlayAlert()`.
4. Standard module settings use `CVA:GetModuleDB()`.
5. User-facing descriptions explain behavior, not implementation details.
6. Avoid permanent polling; prefer events/hooks/bounded retries.
7. Module/UI code must not leave hidden EditBoxes focused.
8. Parent-disabled UI must make descendants non-interactive without deleting their settings.
9. Warning-time range must represent the mechanic's real meaningful maximum lifetime.
10. Project author metadata belongs to the project maintainer; AI tooling is not listed as `## Author`.


## Project packaging convention

Official feature modules use physical AddOn IDs `ClassVoiceAlertToolbox_Module_<Feature>`, depend on `ClassVoiceAlertToolbox_Core`, and group under `ClassVoiceAlertToolbox`. Blizzard-facing `## Title` and `## Author` metadata are English-title / `Clory` respectively.
