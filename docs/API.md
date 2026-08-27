# ClassVoiceAlert Core API

Runtime API Version: **1**

Project version and Runtime API version are independent.

For example:

```text
ClassVoiceAlert release: 0.1.0
CVA.API_VERSION:         1
```

The release version changes whenever the suite is released.

`CVA.API_VERSION` changes only when the Core introduces a breaking module API change.

---

## 1. Bootstrap

Every feature module begins by obtaining the public Core object:

```lua
local ADDON_NAME = ...

local CVA = _G.ClassVoiceAlert
if not CVA or CVA:GetAPIVersion() < 1 then
    return
end
```

Current public global:

```lua
_G.ClassVoiceAlert
```

Compatibility alias may exist internally, but new modules should use:

```lua
_G.ClassVoiceAlert
```

---

## 2. API version

### `CVA:GetAPIVersion()`

Returns the current runtime API version.

Example:

```lua
if CVA:GetAPIVersion() < 1 then
    return
end
```

A feature module should declare its required version during registration:

```lua
requiredCoreAPI = 1
```

---

## 3. Global database

### `CVA:GetDB()`

Returns the complete ClassVoiceAlert persistent database.

Feature modules normally should not manipulate the complete database directly.

Prefer:

```lua
CVA:GetGlobalDB()
CVA:GetModuleDB(...)
```

---

### `CVA:GetGlobalDB()`

Returns shared Core settings.

Conceptually:

```lua
{
    soundChannel = "Master",
    ttsVoiceID = nil,
    ttsVolume = 100,
}
```

Feature modules must not duplicate these settings.

---

### `CVA:GetModuleDB(classID, moduleID, defaults)`

Returns the persistent database table for a feature module.

Example:

```lua
local CLASS_ID = "DEATHKNIGHT"
local MODULE_ID = "example"

local defaults = {
    enabled = true,

    alerts = {
        main = {
            enabled = true,
            warnBefore = 5,
            mode = "blizzard",
            selectedSound = nil,
            selectedCustomSound = nil,
            selectedBlizzardSound = "RAID_WARNING",
            ttsText = "示例提醒",
        },
    },
}

local db = CVA:GetModuleDB(
    CLASS_ID,
    MODULE_ID,
    defaults
)
```

Persistent location is managed by Core under:

```text
ClassVoiceAlertDB.modules[classID][moduleID]
```

Modules should not depend on the physical table layout beyond the public API.

---

## 4. Alert-profile normalization

### `CVA:NormalizeAlertProfile(profile, spec)`

Normalizes a standard alert profile and fills required values.

Example:

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

For new modules:

```text
warnStep = 1
```

should be used.

The standard UI currently works in integer seconds.

---

## 5. Warning-time normalization

### `CVA:NormalizeWarningSeconds(value, minValue, maxValue, fallback)`

Core owns standard `warnBefore` normalization.

Normalization:

```text
tonumber
→ math.ceil
→ clamp
```

Example:

```lua
local seconds = CVA:NormalizeWarningSeconds(
    value,
    0,
    30,
    5
)
```

For range `0-30`:

```text
-10  -> 0
50   -> 30
1.2  -> 2
3.01 -> 4
```

If parsing fails, Core retains or restores a valid fallback.

Feature modules must not create a second incompatible parser for standard warning-time fields.

---

## 6. Alert playback

### `CVA:PlayAlert(profile, options)`

This is the standard runtime alert interface.

Example:

```lua
CVA:PlayAlert(db.alerts.main, {
    showError = false,
    defaultText = "示例提醒",
})
```

For a configuration test button:

```lua
CVA:PlayAlert(db.alerts.main, {
    showError = true,
    defaultText = "示例提醒",
})
```

Runtime alerts should normally use:

```lua
showError = false
```

User-initiated tests should normally use:

```lua
showError = true
```

Modules must not bypass `CVA:PlayAlert()` with their own TTS, LSM, or SoundKit implementation.

---

## 7. LibSharedMedia

### `CVA:GetLSM()`

Returns the currently available `LibSharedMedia-3.0` object, if available.

Core follows this invariant:

> Cache only successful LSM resolution.

A failed or nil lookup is never permanently cached.

Feature modules must not call `LibStub()` to create their own LSM subsystem.

---

### `CVA:GetLSMSounds()`

Returns sounds currently available through LibSharedMedia.

---

### `CVA:FetchLSMSound(name)`

Resolves a LibSharedMedia sound name to its media path when available.

Feature modules normally do not need these functions directly when using standard Core UI.

---

## 8. Module registration

### `CVA:RegisterModule(descriptor)`

Registers a feature module with the toolbox.

Example:

```lua
CVA:RegisterModule({
    addon = ADDON_NAME,

    requiredCoreAPI = 1,

    classID = "DEATHKNIGHT",
    className = "死亡骑士",

    moduleID = "example",
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

## 9. Registration fields

### `addon`

Physical AddOn name supplied through:

```lua
local ADDON_NAME = ...
```

---

### `requiredCoreAPI`

Minimum compatible runtime API.

Current value:

```lua
1
```

---

### `classID`

Stable machine-readable class identifier.

Example:

```lua
"DEATHKNIGHT"
```

---

### `className`

User-facing class name used inside the toolbox.

Example:

```lua
"死亡骑士"
```

---

### `moduleID`

Stable machine-readable module identifier.

Examples:

```text
boneshield
dnd
```

Do not change an existing `moduleID` casually because it is part of persistent database identity.

---

### `moduleName`

User-facing module name inside the toolbox.

This may be localized independently of the English Blizzard AddOn-list title.

---

### `order`

Controls ordering inside the ClassVoiceAlert toolbox.

This is separate from the Blizzard AddOns-list order.

---

### `description`

User-facing explanation of what the module does.

Describe functionality, not internal implementation.

Good:

```text
白骨之盾即将结束时进行语音提醒。
```

Avoid:

```text
通过 CDM auraInstanceID rollover 和定时器检查……
```

---

### `enabledLabel`

Label used for the module's master enable control.

---

### `getDB`

Returns the active module database.

---

### `alerts`

Describes alert sections rendered by the standard Core UI.

---

## 10. Standard alert descriptor

Typical descriptor:

```lua
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
}
```

### Warning range

`maxWarnBefore` must reflect the longest meaningful duration of the mechanic.

Examples:

```text
Bone Shield:
maxWarnBefore = 30

DnD lingering state:
maxWarnBefore = 4
```

Do not reduce the range merely to make the slider shorter.

---

## 11. Standard UI behavior

Modules using the standard Core panel automatically receive:

- module enable control;
- alert enable control;
- warning-time slider;
- manual warning-time input;
- sound-source selection;
- TTS text input;
- sound browser;
- test button;
- parent-child enable locking;
- keyboard-focus protection.

Modules should use standard UI unless they genuinely require behavior that the standard descriptor cannot represent.

---

## 12. Custom UI

A module may provide custom configuration UI only when necessary.

Custom UI must preserve framework behavior.

In particular:

- disabled parents must disable child controls;
- configuration values must not be destroyed merely because a control is disabled;
- EditBoxes must not retain hidden keyboard focus;
- modules must not register extra Blizzard Settings pages;
- modules must not register extra slash commands;
- shared audio configuration must remain in Core.

---

## 13. Navigation

Core owns toolbox navigation.

Public user entry point:

```text
/cvat
```

Internal Core navigation APIs may open the toolbox or a specific module.

Feature modules must not create separate public commands solely to open their page.

---

## 14. Legacy migration

Core may expose migration helpers for older versions, including legacy global audio settings.

Legacy migration exists only to preserve existing user configuration.

New modules should not design new independent SavedVariables around these migration APIs.

---

## 15. API compatibility

The following does not require increasing `CVA.API_VERSION`:

- adding an optional descriptor field;
- adding a new helper API;
- changing documentation;
- fixing Core implementation bugs;
- changing UI appearance while preserving module contracts.

A runtime API version increase is appropriate when an existing module written against the previous API can no longer load or behave correctly without source changes.

Example:

```text
API 1 -> API 2
```

should be reserved for a genuine breaking contract change.
