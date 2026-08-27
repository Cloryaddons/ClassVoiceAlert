# Architecture

## 1. Physical AddOn layout

```text
ClassVoiceAlertToolbox              # Root / meta AddOn
ClassVoiceAlertToolbox_Core         # shared Core
ClassVoiceAlertToolbox_Module_BoneShield   # feature module
ClassVoiceAlertToolbox_Module_DnD          # feature module
```

WoW AddOn list should present:

```text
ClassVoiceAlert Toolbox
    ClassVoiceAlert Core
    BoneShieldVoiceAlert
    DnDVoiceAlert
```

All children use:

```toc
## Group: ClassVoiceAlertToolbox
```

Core depends on Root; feature modules depend on Core.

## 2. Responsibility boundary

### Root: `ClassVoiceAlertToolbox`

May own only suite-shell concerns:
- AddOns-list parent metadata
- Blizzard `Settings -> AddOns` entry
- single `/cvat` command
- loading/opening Core UI

Must not own:
- class spell IDs
- alert state machines
- LSM/TTS/media implementation
- module settings data

### Core: `ClassVoiceAlertToolbox_Core`

Owns shared infrastructure:
- `_G.ClassVoiceAlert`
- runtime API version
- `ClassVoiceAlertDB`
- defaults and migration helpers
- module registry and class navigation
- standard module UI
- global audio UI
- sound browser
- LSM integration
- compatible custom voice provider integration
- Blizzard SoundKit presets
- TTS discovery/playback
- keyboard-focus safety
- `CVA:PlayAlert()`

Core must remain class-agnostic. Spell IDs and mechanic state machines do not belong here.

### Feature modules

Own only feature-specific behavior:
- spell/aura IDs
- event hooks
- state machines
- bounded scans/retries when unavoidable
- the decision of *when* to alert
- alert descriptors/defaults
- legacy module migration where needed

Feature modules call Core to store/display/play alerts.

> Core = how to play/store/display. Module = when to alert.

## 3. Runtime dependency graph

```text
ClassVoiceAlertToolbox
        ^
        |
ClassVoiceAlertToolbox_Core
        ^
        |
Feature modules
```

Feature modules use:

```toc
## Dependencies: ClassVoiceAlertToolbox_Core
## Group: ClassVoiceAlertToolbox
```

## 4. Public command/settings ownership

Only Root may register:
- Slash commands
- Blizzard Settings categories

The only public slash command is:

```text
/cvat
```

## 5. Media ownership

Only Core owns LSM/TTS/media discovery and playback.

The critical LSM invariant is:
- cache a successfully resolved `LibSharedMedia-3.0` object;
- never cache a failed/nil lookup.

This preserves recovery when load order changes.

Runtime alerts go through:

```lua
CVA:PlayAlert(profile, options)
```

## 6. UI safety

A hidden focused `EditBox` can consume gameplay keys. Core therefore owns keyboard-focus cleanup.

Rules:
- clear focus before hiding/switching a panel containing an EditBox;
- clear focus when disabling an EditBox;
- Enter commits numeric warning-time edits by causing focus loss;
- Escape cancels the unfinished numeric edit and clears focus;
- modules should not use raw keyboard handlers or override bindings.

## 7. Enable hierarchy

```text
module enabled
    -> alert enabled
        -> detail controls
```

- module off: child alert toggles and detail controls disabled/dimmed;
- module on + alert off: alert toggle remains available; detail controls disabled/dimmed;
- disabling does not erase stored configuration.

## 8. Warning-time semantics

Standard `warnBefore` is integer seconds.

Each alert declares the real meaningful lifetime range, e.g.:
- Bone Shield `0..30`
- DnD sticky state `0..4`

Manual values normalize as:
1. parse number;
2. invalid input -> retain current valid value;
3. `math.ceil()`;
4. clamp to min/max.

## 9. Performance constraints

Prefer events, callbacks, hooks and bounded delayed scans.

Do not add permanent high-frequency polling without a documented unavoidable reason. In particular, feature modules should not introduce:
- permanent `OnUpdate` loops;
- permanent `C_Timer.NewTicker` polling;
- `while true` loops.

## 10. Source-of-truth rule

Repository source is authoritative:
- addon code: `addons/`
- API contract: `docs/API.md`
- architecture: `docs/ARCHITECTURE.md`
- module rules: `docs/MODULE_DEVELOPMENT.md`
- version: `VERSION`

Do not keep parallel hand-edited copies of these documents inside individual AddOn folders.


### AddOn-list child ordering

Blizzard does not expose a TOC metadata field for explicit ordering of children inside a `Group`. The current client sorts grouped AddOns by internal AddOn index, which follows the physical AddOn-name scan order for normal custom AddOns.

To keep Core before all feature modules, official feature AddOn IDs MUST use the `ClassVoiceAlertToolbox_Module_` prefix:

```text
ClassVoiceAlertToolbox
ClassVoiceAlertToolbox_Core
ClassVoiceAlertToolbox_Module_BoneShield
ClassVoiceAlertToolbox_Module_DnD
```

Do not rename a feature AddOn back to `ClassVoiceAlertToolbox_<Feature>`, because a feature beginning with `B` would sort before `_Core`. User-facing `## Title` values are independent of these physical AddOn IDs.
