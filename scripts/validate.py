#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDONS = ROOT / "addons"
AUTHOR = "Clory"
ROOT_ADDON = "ClassVoiceAlertToolbox"
CORE_ADDON = "ClassVoiceAlertToolbox_Core"
EXPECTED = {
    ROOT_ADDON,
    CORE_ADDON,
    "ClassVoiceAlertToolbox_Module_BoneShield",
    "ClassVoiceAlertToolbox_Module_DnD",
}
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")

errors: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"Missing file: {path.relative_to(ROOT)}")
        return ""


def toc_field(text: str, key: str) -> str | None:
    match = re.search(rf"^## {re.escape(key)}:\s*(.+?)\s*$", text, re.MULTILINE)
    return match.group(1) if match else None


def main() -> int:
    version = read(ROOT / "VERSION").strip()
    if not SEMVER.fullmatch(version):
        fail(f"VERSION must be X.Y.Z; got {version!r}")

    actual = {p.name for p in ADDONS.iterdir() if p.is_dir()} if ADDONS.exists() else set()
    if actual != EXPECTED:
        fail(f"addons/ set mismatch. expected={sorted(EXPECTED)} actual={sorted(actual)}")

    toc_text: dict[str, str] = {}
    for addon in sorted(EXPECTED):
        toc = ADDONS / addon / f"{addon}.toc"
        text = read(toc)
        toc_text[addon] = text
        if toc_field(text, "Author") != AUTHOR:
            fail(f"{addon}: ## Author must be {AUTHOR}")
        if toc_field(text, "Version") != version:
            fail(f"{addon}: ## Version must match VERSION ({version})")
        if toc_field(text, "Group") != ROOT_ADDON:
            fail(f"{addon}: ## Group must be {ROOT_ADDON}")

    if toc_field(toc_text.get(CORE_ADDON, ""), "Dependencies") != ROOT_ADDON:
        fail(f"{CORE_ADDON}: dependency must be {ROOT_ADDON}")

    expected_titles = {
        ROOT_ADDON: "ClassVoiceAlert Toolbox",
        CORE_ADDON: "ClassVoiceAlert Core",
        "ClassVoiceAlertToolbox_Module_BoneShield": "BoneShieldVoiceAlert",
        "ClassVoiceAlertToolbox_Module_DnD": "DnDVoiceAlert",
    }
    for addon, expected_title in expected_titles.items():
        if toc_field(toc_text.get(addon, ""), "Title") != expected_title:
            fail(f"{addon}: ## Title must be {expected_title}")

    for addon in sorted(EXPECTED - {ROOT_ADDON, CORE_ADDON}):
        if not addon.startswith("ClassVoiceAlertToolbox_Module_"):
            fail(f"{addon}: feature AddOn ID must use ClassVoiceAlertToolbox_Module_ prefix so Core sorts first")

    for addon in sorted(EXPECTED - {ROOT_ADDON, CORE_ADDON}):
        text = toc_text.get(addon, "")
        if toc_field(text, "Dependencies") != CORE_ADDON:
            fail(f"{addon}: dependency must be {CORE_ADDON}")
        if toc_field(text, "X-ClassVoiceAlert-Module") != "true":
            fail(f"{addon}: missing X-ClassVoiceAlert-Module: true")

    root_lua = read(ADDONS / ROOT_ADDON / "Root.lua")
    if f'local ROOT_VERSION = "{version}"' not in root_lua:
        fail("Root.lua ROOT_VERSION is not synchronized")
    if "/cvat" not in root_lua:
        fail("Root.lua must own /cvat")

    init_lua = read(ADDONS / CORE_ADDON / "Init.lua")
    if f'CVA.VERSION = "{version}"' not in init_lua:
        fail("Core Init.lua CVA.VERSION is not synchronized")
    if not re.search(r"^CVA\.API_VERSION = 1\s*$", init_lua, re.MULTILINE):
        fail("Core runtime API version must currently remain 1")

    non_root_files = []
    for addon in sorted(EXPECTED - {ROOT_ADDON}):
        non_root_files.extend((ADDONS / addon).glob("*.lua"))
    for path in non_root_files:
        text = read(path)
        if re.search(r"\bSLASH_[A-Z0-9_]+", text) or "SlashCmdList" in text:
            fail(f"{path.relative_to(ROOT)}: only Root may register slash commands")
        if "Settings.RegisterCanvasLayoutCategory" in text or "Settings.RegisterAddOnCategory" in text:
            fail(f"{path.relative_to(ROOT)}: only Root may register Blizzard Settings")

    feature_dirs = EXPECTED - {ROOT_ADDON, CORE_ADDON}
    banned_feature_patterns = {
        r"LibSharedMedia-3\.0": "feature module must not implement LSM",
        r"\bLibStub\b": "feature module must not call LibStub",
        r"C_VoiceChat\.SpeakText": "feature module must not call TTS directly",
        r"(?<![A-Za-z0-9_:.])PlaySound\s*\(": "feature module must not call PlaySound directly",
        r"(?<![A-Za-z0-9_:.])PlaySoundFile\s*\(": "feature module must not call PlaySoundFile directly",
        r"C_Timer\.NewTicker": "feature module must not add permanent ticker polling",
        r"SetScript\s*\(\s*[\"']OnUpdate[\"']": "feature module must not add OnUpdate polling",
        r"while\s+true\s+do": "feature module must not add while-true loops",
        r"EnableKeyboard\s*\(\s*true\s*\)": "feature module must not capture raw keyboard input",
        r"SetOverrideBinding": "feature module must not install override bindings",
    }
    for addon in sorted(feature_dirs):
        for path in (ADDONS / addon).glob("*.lua"):
            text = read(path)
            for pattern, reason in banned_feature_patterns.items():
                if re.search(pattern, text):
                    fail(f"{path.relative_to(ROOT)}: {reason}")
            if "CVA:PlayAlert" not in text:
                fail(f"{path.relative_to(ROOT)}: feature module should route alerts through CVA:PlayAlert")

    # LSM invariant: Core may cache success, but must not cache failed lookup.
    media = read(ADDONS / CORE_ADDON / "Media.lua")
    if "function CVA:GetLSM()" not in media:
        fail("Core Media.lua missing CVA:GetLSM")

    # Public author metadata must never regress to an AI-tool author.
    for path in ADDONS.rglob("*.toc"):
        text = read(path).lower()
        if "## author: chatgpt" in text or "## author: openai" in text:
            fail(f"{path.relative_to(ROOT)}: AI tooling must not be listed as project author")

    if errors:
        print("Validation failed:", file=sys.stderr)
        for item in errors:
            print(f"  - {item}", file=sys.stderr)
        return 1

    print(f"Validation passed for ClassVoiceAlert {version}")
    print("Checked versions, authorship, grouping/dependencies, ownership boundaries, and feature-module safety rules.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
