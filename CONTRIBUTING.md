# Contributing

This project is currently maintainer-driven.

For bugs, please open an issue with:
- WoW version / Interface version
- ClassVoiceAlert version
- affected module
- exact reproduction steps
- Lua error text if present
- whether the issue reproduces with unrelated AddOns disabled

For code changes:
1. keep class mechanics in feature modules;
2. keep shared media/UI/storage in Core;
3. run `python scripts/validate.py`;
4. test in game;
5. describe behavior changes and migration impact in the pull request.

Do not list AI coding tools as project authors in TOC metadata.
