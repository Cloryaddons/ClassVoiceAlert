# Release Process

The repository uses one unified semantic version for Root, Core and official feature modules.

## Normal release

Example: release `0.1.1`.

```bash
python scripts/set_version.py 0.1.1
python scripts/validate.py
python scripts/package.py
```

Test the generated `dist/ClassVoiceAlertSuite-0.1.1.zip` in WoW.

Then:

```bash
git add .
git commit -m "Release 0.1.1"
git push origin main

git tag v0.1.1
git push origin v0.1.1
```

Push `main` **before** the tag. The release workflow then:
1. checks out the tagged source;
2. validates repository invariants;
3. packages `addons/`;
4. creates a GitHub Release;
5. uploads `ClassVoiceAlertSuite-0.1.1.zip`.

## Versioning

- `VERSION` is the only Suite version source.
- `scripts/set_version.py` synchronizes TOCs plus Root/Core Lua display versions.
- `CVA.API_VERSION` is separate; increment it only for a breaking module-facing API change.

## Before tagging

Verify:
- no Lua errors;
- AddOn grouping after full restart if TOCs changed;
- `/cvat` and Blizzard Settings entry;
- module parent/child enable behavior;
- EditBox focus safety (`ESC`, `C` after closing UI);
- Bone Shield and DnD behavior in actual combat/testing;
- `python scripts/validate.py` passes;
- release ZIP contains four AddOn directories at archive root, not an extra `addons/` directory.
