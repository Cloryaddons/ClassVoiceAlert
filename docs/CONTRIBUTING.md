# Contributing to ClassVoiceAlert

Thanks for your interest in ClassVoiceAlert.

ClassVoiceAlert is currently maintained by **Clory**.

Before changing framework or module code, please read:

```text
docs/ARCHITECTURE.md
docs/API.md
docs/MODULE_DEVELOPMENT.md
```

---

## Reporting bugs

Please use GitHub Issues when possible.

A useful bug report includes:

- WoW version;
- ClassVoiceAlert version;
- affected module;
- reproduction steps;
- Lua error text, if available;
- whether the issue remains with unrelated AddOns disabled.

Avoid including account credentials, personal information, or private tokens in reports.

---

## Feature requests

Feature requests are welcome through GitHub Issues.

For a new alert module, describe:

- class/spec;
- mechanic being monitored;
- when the alert should fire;
- expected warning-time range;
- whether multiple independent alert conditions are needed.

Implementation details can be determined separately.

---

## Development workflow

Create a branch:

```bash
git switch -c feature/example
```

or:

```bash
git switch -c fix/example
```

Before submitting changes:

```bash
python scripts/validate.py
python scripts/package.py
```

Test the generated package in World of Warcraft.

---

## Architecture requirements

Contributions must preserve the Core/module boundary:

> Core decides how to alert.  
> Modules decide when to alert.

Feature modules must not duplicate:

- LibSharedMedia handling;
- TTS implementation;
- Blizzard sound infrastructure;
- shared audio settings;
- standard sound browser;
- Blizzard Settings registration;
- slash commands.

The only public slash command is:

```text
/cvat
```

---

## Module naming

Official modules use:

```text
ClassVoiceAlertToolbox_Module_<ModuleName>
```

Their Blizzard AddOn-list titles should be English.

Official project metadata uses:

```toc
## Author: Clory
```

---

## Code and performance

Prefer event-driven logic.

Avoid unnecessary permanent polling, `OnUpdate` loops, or high-frequency tickers.

Do not introduce unbounded loops.

Configuration UI must not retain hidden keyboard focus or interfere with normal WoW key bindings.

---

## Pull requests

Keep pull requests focused on one logical change when possible.

Explain:

```text
What changed?
Why was it needed?
How was it tested?
```

Changes affecting Core architecture or the public API should update the relevant documentation in the same pull request.
