# Release checklist — v0.12.0 (Phase 12)

✔ = done and verified · ☐ = needs the project owner (cannot be done from the build machine)

## Build
- ✔ Version `0.12.0` in `project/project.godot`; Android `version/code` 12 (`project/export_presets.cfg`).
- ✔ Export presets: **Android** (arm64-v8a, immersive, landscape), **Windows Desktop** (single .exe), **Linux**. Tests are excluded from exports.
- ✔ `tools/build.sh` — runs all checks, exports the data pack for every preset and boots the exported game (BOOT_OK). Verified 2026-11-22: all three packs export; the exported pack loads the dojo and a full Stormcrag expedition.
- ✔ Original app icon (`project/icon.svg`).
- ☐ **Export templates** for Godot 4.5.1 (Editor → Manage Export Templates → Download, or the official `.tpz`) — the build script then produces the .exe / Linux binary.
- ☐ **Android:** Android SDK + Java 17 + a release keystore (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD`). Keep the keystore private and backed up — you cannot update a store app without it.
- ☐ **Package name:** `com.iwanttobeninja.game` is a placeholder — change it to one you own before the first store upload (it can never change afterwards).

## Quality
- ✔ All automated checks pass (`tools/check.sh`: import/parse, boot test, every test suite with a script-error guard, main-scene smoke run). See CHANGELOG for the count.
- ✔ QA edge cases covered by tests (`qa_test.gd`): crash-safe saves + recovery from a damaged save; quitting/restarting keeps gathered materials; arena after timeout ignored; dying in the arena keeps the boss wounded and the timer gone; switching apps pauses; lock-on releases on a kill; a boss killed mid-telegraph never lands its attack; top-down camera survives a respawn; old saves with removed gear/items; mud and climbing state cleared on respawn.
- ✔ Every boss attack telegraphs (tests per boss) and has a warning sound.
- ✔ The 45:00 minimum countdown holds on every difficulty (test).
- ✔ Performance budgets met on all presets (`docs/PERFORMANCE.md`).
- ☐ **Phone frame rate:** dojo → Settings → Run benchmark on the target phone (needs "TARGET MET").
- ☐ **Human playtest** on PC (keyboard+mouse and gamepad) and on the phone (touch): the manual checklist below.

## Content and legal
- ✔ `assets/ASSET_LEDGER.md` lists every shipped asset: the owner's Mixamo ninja (Mixamo terms) and our own generated art/audio/icon. Concept art is reference-only and not in the project folder (not exported).
- ☐ If the repository becomes public: move the Mixamo GLB to private storage (Mixamo forbids redistributing the raw files).
- ✔ `docs/KNOWN_ISSUES.md` is current.

## Settings and accessibility (all saved in `user://settings.cfg`)
- ✔ Graphics Auto/Low/Medium/High · Difficulty Easy/Normal/Hard · Master/Music/SFX volume · touch button size · screen shake · bold attack warnings · control remapping (keyboard/mouse + gamepad, swap on conflict, reset).
- ✔ Progress in `user://profile.json` with `.bak` backup.

## Manual playtest checklist (owner)
1. Fresh install → dojo opens; Settings shows Graphics "Auto (Low)" on the phone, "Auto (High)" on PC.
2. Verdant Canopy hunt on Normal: timer starts at 45:00, gather a glowcap, light a shrine, climb the rampart, cross the gorge, enter the arena (timer disappears), break the antlers, defeat Kurogale, rewards shown and saved.
3. Back in the dojo: forge the Ember Charm, equip it; start Emberwild (unlocked).
4. Mid-hunt: pause (timer frozen), switch to another app and back (pause menu is open), Restart (materials kept), Back to hunt board (materials kept).
5. Settings: rebind Jump to another key / button, play briefly, restart the app — the binding is kept; Reset controls.
6. Touch: joystick + every button; set touch button size to the maximum — all buttons on screen; turn screen shake off.
7. Difficulty Easy then Hard on the same boss: Easy feels forgiving, Hard punishing; warnings never shorter.
8. Run the benchmark (phone).
9. Moonfen and Stormcrag full hunts (unlock chain: Kurogale → Tortoise → Nami → Sky Roc).
