# ClassVoiceAlert Release Process

This document describes the official release workflow for ClassVoiceAlert.

The GitHub repository is the source of truth.

Released tags are immutable.

---

## 1. Version source

The repository root contains:

```text
VERSION
```

This is the authoritative suite release version.

Example:

```text
0.1.0
```

Official Root, Core, and bundled modules use the same suite version.

Runtime API compatibility is separate:

```lua
CVA.API_VERSION = 1
```

Do not change the API version merely because the suite version changes.

---

## 2. Versioning rules

ClassVoiceAlert uses semantic-style versions:

```text
MAJOR.MINOR.PATCH
```

During pre-1.0 development:

```text
0.1.0
0.1.1
0.2.0
...
```

Typical usage:

```text
0.1.0 -> 0.1.1
bug fix / small correction

0.1.x -> 0.2.0
new user-facing feature or new module

1.0.0
first mature stable release
```

A released tag must never be silently replaced.

If `v0.1.0` has a bug, publish `v0.1.1`.

---

## 3. Normal development

Start from an up-to-date `main`:

```bash
git checkout main
git pull
```

Create a branch when appropriate:

```bash
git switch -c feature/example
```

or:

```bash
git switch -c fix/example
```

Make and test the change.

---

## 4. Local validation

Before packaging:

```bash
python scripts/validate.py
```

Validation should complete successfully before release.

The validation script protects framework invariants such as:

- AddOn structure;
- version consistency;
- Author metadata;
- dependencies;
- grouping;
- module naming;
- forbidden duplicate audio systems;
- public command ownership;
- Core API compatibility.

---

## 5. Local packaging

Generate the installation ZIP:

```bash
python scripts/package.py
```

Output:

```text
dist/ClassVoiceAlertSuite-x.y.z.zip
```

The ZIP root must directly contain AddOn folders.

Correct:

```text
ClassVoiceAlertToolbox/
ClassVoiceAlertToolbox_Core/
ClassVoiceAlertToolbox_Module_BoneShield/
ClassVoiceAlertToolbox_Module_DnD/
```

Incorrect:

```text
addons/
    ClassVoiceAlertToolbox/
    ...
```

---

## 6. In-game release testing

Before publishing a release, test the ZIP produced by the packaging process.

Do not rely only on loose development files.

Recommended process:

```text
1. Exit WoW.
2. Remove the currently installed ClassVoiceAlert AddOn folders.
3. Install the generated release ZIP.
4. Start WoW.
5. Confirm AddOn grouping.
6. Open /cvat.
7. Test all affected modules.
8. Test audio sources.
9. Test warning-time controls.
10. Confirm normal keyboard bindings still work after closing the UI.
```

A release should not be tagged until the packaged build passes this test.

---

## 7. Preparing a new release

Example release:

```text
0.1.1
```

Update versions using:

```bash
python scripts/set_version.py 0.1.1
```

Then validate:

```bash
python scripts/validate.py
```

Package:

```bash
python scripts/package.py
```

Perform final in-game testing.

---

## 8. Commit the release

After testing:

```bash
git add .
git commit -m "Release 0.1.1"
git push origin main
```

Confirm GitHub `main` contains the expected release source.

---

## 9. Tag the release

Create the immutable release tag:

```bash
git tag v0.1.1
git push origin v0.1.1
```

The repository's release workflow may automatically:

```text
validate source
→ package suite
→ create GitHub Release
→ attach ClassVoiceAlertSuite-0.1.1.zip
```

---

## 10. Verify GitHub Release

After the workflow succeeds:

1. Open GitHub Releases.
2. Open the new version.
3. Download the generated ZIP.
4. Confirm the filename.
5. Confirm the ZIP layout.
6. Preferably perform one final installation test from the downloaded GitHub artifact.

The artifact downloaded by users should be the same artifact that was validated.

---

## 11. Release notes

Release notes should describe player-visible changes.

Example:

```markdown
## ClassVoiceAlert 0.1.1

### Fixed

- Fixed keyboard focus occasionally blocking normal WoW key bindings.
- Fixed disabled alerts allowing child settings to remain editable.

### Changed

- Improved warning-time input handling.
```

Avoid filling public release notes with internal implementation details unless they are relevant to developers.

---

## 12. Documentation-only changes

Changes such as:

```text
README cleanup
typo fixes
documentation clarification
screenshots
contribution instructions
```

do not require a new AddOn release version unless they change the distributed AddOn package.

They may be committed directly as documentation changes.

---

## 13. Runtime API changes

Do not increase:

```lua
CVA.API_VERSION
```

for ordinary releases.

Increase it only when a previously valid feature module must change its source code to remain compatible with Core.

Breaking API changes should also update:

```text
docs/API.md
docs/ARCHITECTURE.md
docs/MODULE_DEVELOPMENT.md
docs/MODULE_TEMPLATE.lua
```

---

## 14. Release checklist

Before tagging:

- `VERSION` is correct;
- all bundled AddOn versions match;
- `python scripts/validate.py` passes;
- `python scripts/package.py` succeeds;
- packaged ZIP structure is correct;
- packaged ZIP has been tested in WoW;
- affected modules behave correctly;
- `/cvat` works;
- no keyboard-focus regression;
- CHANGELOG is updated if appropriate;
- release commit is pushed to `main`.

After tagging:

- GitHub Action succeeds;
- GitHub Release exists;
- correct ZIP is attached;
- downloaded Release ZIP is valid.
