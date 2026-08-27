# Module Development Guide

## Goal

A feature module should contain only the logic required to determine **when** an alert should fire.

Before adding a module, read:
1. `docs/ARCHITECTURE.md`
2. `docs/API.md`
3. `docs/MODULE_TEMPLATE.lua`

## Create a new module

Example: Dancing Rune Weapon.

### 1. Create the physical AddOn

```text
addons/ClassVoiceAlertToolbox_Module_DancingRuneWeapon/
    ClassVoiceAlertToolbox_Module_DancingRuneWeapon.toc
    DancingRuneWeapon.lua
```

### 2. TOC

```toc
## Interface: 120100
## Title: DancingRuneWeaponVoiceAlert
## Notes: Dancing Rune Weapon voice alert module for ClassVoiceAlert.
## Author: Clory
## Version: 0.1.0
## Dependencies: ClassVoiceAlertToolbox_Core
## Group: ClassVoiceAlertToolbox
## X-ClassVoiceAlert-Module: true
## X-ClassVoiceAlert-Class: DEATHKNIGHT
## X-ClassVoiceAlert-ModuleID: dancingRuneWeapon
## X-ClassVoiceAlert-ModuleName: 符文刃舞提醒

DancingRuneWeapon.lua
```

The repository version is updated by `scripts/set_version.py`; do not independently version a module.

### 3. Start from the template

Copy `docs/MODULE_TEMPLATE.lua` and replace IDs, labels, defaults and trigger logic.

### 4. Declare warning range honestly

If the relevant state can meaningfully exist for 12 seconds:

```lua
minWarnBefore = 0,
maxWarnBefore = 12,
warnStep = 1,
```

Do not shorten the range merely to simplify the UI.

### 5. Trigger the alert through Core

```lua
CVA:PlayAlert(profile, {
    showError = false,
    defaultText = "提醒文本",
})
```

Do not implement another media backend.

## Forbidden duplication in feature modules

Do not add module-local implementations of:
- `LibSharedMedia-3.0` lookup/caching
- TTS voice discovery or `SpeakText`
- Blizzard SoundKit preset registry
- custom voice provider manifest/browser
- global sound channel / TTS voice / TTS volume UI
- sound browser
- Blizzard Settings registration
- slash commands

## Polling / performance

Prefer:
- game events
- secure/normal hooks where appropriate
- Cooldown Manager callbacks
- bounded delayed retries

Avoid permanent high-frequency tickers or `OnUpdate` state polling unless there is no event-driven alternative and the reason is documented.

## UI

Use Core standard UI whenever possible.

If a custom panel is genuinely needed:
- preserve module -> alert -> detail enable hierarchy;
- clear EditBox focus before hiding/disabling;
- do not intercept gameplay keyboard bindings;
- keep shared TTS voice/volume/channel global.

## Pre-commit checklist

Run:

```bash
python scripts/validate.py
```

Then verify in game:
- `/cvat` opens correctly;
- AddOn list grouping is correct after a full client restart if TOC metadata changed;
- module disabled -> child settings are locked;
- alert disabled -> its detail settings are locked;
- TTS/search/numeric input does not leave keyboard focus behind;
- `ESC` and normal keybinds such as `C` work after closing the toolbox;
- runtime alert behavior is correct in the relevant mechanic cases.


## Public metadata conventions

- `## Author` MUST be `Clory` for this project.
- User-facing AddOns-list `## Title` values MUST be English.
- Feature physical AddOn IDs MUST start with `ClassVoiceAlertToolbox_Module_` so `ClassVoiceAlertToolbox_Core` stays before feature modules in the grouped AddOns list.
- Chinese names may still be used inside the toolbox UI for class/module navigation; this rule only governs Blizzard-facing AddOn titles and metadata.
