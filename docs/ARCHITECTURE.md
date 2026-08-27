# ClassVoiceAlert Architecture

ClassVoiceAlert is a modular voice-alert framework for World of Warcraft.

Author: **Clory**

This document defines the architectural boundaries of the project.  
These rules should remain stable even as individual modules are added, removed, or rewritten.

---

## 1. Project structure

The installed suite consists of one Root AddOn, one Core AddOn, and multiple feature modules.

```text
ClassVoiceAlert Toolbox
    ClassVoiceAlert Core
    BoneShieldVoiceAlert
    DnDVoiceAlert
```

Physical AddOn IDs:

```text
ClassVoiceAlertToolbox
ClassVoiceAlertToolbox_Core
ClassVoiceAlertToolbox_Module_BoneShield
ClassVoiceAlertToolbox_Module_DnD
```

Future feature modules must use:

```text
ClassVoiceAlertToolbox_Module_<ModuleName>
```

This naming convention keeps the Core before feature modules in the WoW AddOns list and gives all feature modules a consistent namespace.

---

## 2. Root responsibilities

Physical AddOn:

```text
ClassVoiceAlertToolbox
```

The Root is intentionally thin.

It owns:

- the parent entry in the WoW AddOns list;
- the `/cvat` slash command;
- the Blizzard `Options -> AddOns` entry;
- opening the ClassVoiceAlert configuration interface.

It must not own:

- class mechanics;
- spell IDs;
- aura tracking;
- module state machines;
- LibSharedMedia implementation;
- TTS implementation;
- alert playback logic;
- module SavedVariables.

The Root is the suite entry point, not the framework implementation.

---

## 3. Core responsibilities

Physical AddOn:

```text
ClassVoiceAlertToolbox_Core
```

The Core owns shared framework services.

These include:

- `ClassVoiceAlertDB`;
- database defaults and migrations;
- module registry;
- class/module navigation;
- shared configuration UI;
- standard alert UI controls;
- Blizzard SoundKit support;
- LibSharedMedia support;
- compatible custom voice-pack support;
- WoW TTS support;
- global sound channel;
- global TTS voice and volume;
- sound browser;
- warning-time controls;
- keyboard-focus safety;
- alert playback through `CVA:PlayAlert()`.

The Core answers:

> How is an alert stored, configured, displayed, and played?

The Core must not answer:

> When should a specific class mechanic trigger an alert?

---

## 4. Module responsibilities

Feature modules contain only mechanic-specific logic.

Examples:

```text
BoneShieldVoiceAlert
    -> Bone Shield tracking and trigger logic

DnDVoiceAlert
    -> Death and Decay / lingering-effect tracking and trigger logic
```

A feature module owns:

- spell IDs required by that mechanic;
- aura/event observations;
- local state machines;
- mechanic-specific timers;
- conditions determining when an alert should fire;
- module-specific defaults;
- module registration metadata.

A feature module does not own:

- LibSharedMedia initialization;
- TTS implementation;
- Blizzard sound lists;
- custom voice-pack discovery;
- sound-channel settings;
- shared sound browser UI;
- global TTS settings;
- Blizzard Settings registration;
- slash commands.

The architectural boundary is:

> **Core decides how to alert.  
> Module decides when to alert.**

---

## 5. AddOn hierarchy

All suite components visually belong to:

```toc
## Group: ClassVoiceAlertToolbox
```

The Core depends on the Root:

```toc
## Dependencies: ClassVoiceAlertToolbox
```

Feature modules depend on the Core:

```toc
## Dependencies: ClassVoiceAlertToolbox_Core
## Group: ClassVoiceAlertToolbox
```

Therefore the logical dependency chain is:

```text
Root
  ↓
Core
  ↓
Feature modules
```

while the WoW AddOns list presents:

```text
ClassVoiceAlert Toolbox
    ClassVoiceAlert Core
    BoneShieldVoiceAlert
    DnDVoiceAlert
```

---

## 6. Public AddOn metadata

Public AddOn-list titles are English.

Current titles:

```text
ClassVoiceAlert Toolbox
ClassVoiceAlert Core
BoneShieldVoiceAlert
DnDVoiceAlert
```

The author field for this project is:

```toc
## Author: Clory
```

User-facing configuration text inside the toolbox may be Chinese.

Do not use ChatGPT, OpenAI, or another development tool as the AddOn author.

---

## 7. Database architecture

The active framework database is:

```text
ClassVoiceAlertDB
```

Shared global settings are stored once.

Conceptually:

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
            [moduleID] = {
                -- module-specific settings
            },
        },
    },
}
```

Feature modules obtain their database through:

```lua
CVA:GetModuleDB(classID, moduleID, defaults)
```

New modules must not introduce independent SavedVariables merely for convenience.

Legacy SavedVariables may temporarily remain only when required for migration compatibility.

---

## 8. Audio architecture

All runtime alert playback must go through:

```lua
CVA:PlayAlert(profile, options)
```

Modules must not directly implement:

```lua
PlaySound(...)
C_VoiceChat.SpeakText(...)
LibStub("LibSharedMedia-3.0")
```

or equivalent duplicate playback systems.

### LibSharedMedia invariant

Only Core owns LibSharedMedia lookup.

A failed or `nil` lookup must never be permanently cached.

Only a successfully resolved `LibSharedMedia-3.0` object may be cached.

This preserves recovery when load order causes LibSharedMedia to become available later.

---

## 9. Standard alert configuration

Standard alert profiles may contain:

```lua
{
    enabled = true,
    warnBefore = 5,

    mode = "blizzard",

    selectedSound = nil,
    selectedCustomSound = nil,
    selectedBlizzardSound = "RAID_WARNING",

    ttsText = "提醒内容",
}
```

Supported sound modes are owned by Core.

Current modes:

```text
custom
lsm
blizzard
tts
```

Shared settings such as TTS voice, TTS volume, and sound channel belong to the global Core configuration and must not be duplicated per alert.

---

## 10. Warning-time architecture

All standard warning times use integer seconds.

Every alert declares the real meaningful range of the underlying mechanic.

Examples:

```text
Bone Shield:
0-30 seconds

DnD lingering state:
0-4 seconds
```

Do not artificially shorten the allowed range for UI convenience.

Standard warning controls consist of:

```text
slider + numeric input
```

Core normalizes manually entered values in this order:

```text
parse
→ round upward
→ clamp to valid range
```

Examples for a `0-30` range:

```text
-10   -> 0
50    -> 30
1.2   -> 2
3.01  -> 4
30.1  -> 30
```

Invalid non-numeric input restores the previous valid value.

---

## 11. Parent-child UI state

The standard UI follows strict parent-child enable rules.

If a module is disabled:

```text
Module disabled
    -> all child alert settings disabled
```

If the module is enabled but one alert is disabled:

```text
Alert checkbox remains enabled
    -> that alert's detailed settings are disabled
```

Disabling a parent must not erase existing child configuration.

Re-enabling restores access to the previous values.

---

## 12. Keyboard-focus safety

Configuration UI must never interfere with normal WoW key bindings after it is hidden or disabled.

Any EditBox owned by ClassVoiceAlert must:

- use `SetAutoFocus(false)`;
- release focus when appropriate;
- clear focus before being hidden or disabled;
- release focus when its containing panel closes;
- handle Escape without leaving hidden keyboard focus behind.

Feature modules must not:

- register raw keyboard handlers unnecessarily;
- use override bindings;
- capture normal gameplay keys;
- leave hidden EditBoxes focused.

Standard Core UI already implements this behavior.

---

## 13. Polling and performance

Prefer:

```text
events
hooks
bounded delayed retries
```

over:

```text
permanent high-frequency polling
```

Feature modules should not introduce permanent `OnUpdate` loops or high-frequency `C_Timer.NewTicker()` polling unless there is no event-driven alternative and the reason is documented.

Unbounded loops such as:

```lua
while true do
```

are prohibited.

---

## 14. Public commands and Settings

The only public ClassVoiceAlert slash command is:

```text
/cvat
```

Feature modules must not register their own commands.

Only the Root registers the Blizzard Settings entry.

Feature modules must not independently appear under:

```text
Options -> AddOns
```

for configuration purposes.

---

## 15. Source of truth

The GitHub repository is the source of truth.

Development should use:

```text
addons/
```

Official installation packages are generated from that directory.

Do not maintain separate manually edited copies of the same module outside the repository.

Released tags are immutable.

Once:

```text
v0.1.0
```

has been published, fixes must be released as a new version such as:

```text
v0.1.1
```

rather than silently replacing the existing release.
