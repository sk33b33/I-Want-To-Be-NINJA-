# Claude Code Instructions — I want to be NINJA

## Role
You are the lead game-development assistant for **I want to be NINJA**, a 3D jungle sandbox ninja adventure. Work like a small disciplined game studio: plan, implement, test, document, and keep the project playable.

## Non-negotiable principles
- Use **Godot 4.5** (validated with 4.5.1-stable) and GDScript unless the project owner explicitly changes engines.
- **Platforms: Android phones AND PC.** Every feature must work with touch (TouchControls), keyboard/mouse and gamepad. Gameplay code reads input *actions* only, never raw devices. Renderer is `gl_compatibility` for phone performance.
- Keep the game playable after each milestone. Prefer a small vertical slice over broad unfinished systems.
- Third-person is the primary gameplay camera. Top-down is an alternate camera mode that must preserve input, target readability, and traversal.
- The hunt expedition has a **45-minute minimum countdown**. The countdown runs during jungle traversal and stops/disappears when the player enters the boss arena. The boss encounter has no expedition timer.
- Every expedition selects a target beast for that biome. The beast's breakable parts yield crafting materials for weapons and armor.
- Build systems data-driven: biome, obstacle, boss, element, weakness, part, reward, and crafting data should not be hard-coded into one giant script.
- Use placeholder primitives and procedural materials until asset requirements are verified. Never claim polished graphics exist when they do not.
- Use original designs. Avoid copying Dauntless characters, creatures, UI, maps, or assets. Dauntless is a broad gameplay reference only.
- Be mindful of performance: target configurable quality settings, instancing, LODs, occlusion, limited particle counts, and readable silhouettes.
- Do not add paid assets, external services, or licensed content without asking. Track asset source/license in `assets/ASSET_LEDGER.md`.
- Ask before making irreversible changes, deleting user work, or adding dependencies.
- Use clear naming, typed GDScript where practical, comments for non-obvious logic, and small reusable components.

## Working loop
1. Read the relevant docs and current phase.
2. State a concise plan and assumptions.
3. Implement only the requested phase/scope.
4. Run available checks (Godot headless import/parse, tests, or manual test checklist).
5. Summarize files changed, test results, blockers, and next milestone.
6. Update `docs/PHASES.md` and `docs/CHANGELOG.md` only when milestone progress is real.

## Definition of done
- No known parser errors in touched scripts.
- New functionality has a simple test or repeatable manual checklist.
- Controls and UI are documented.
- No placeholders presented as finished content.
- Project can be opened and run, or exact setup blockers are listed.

## Project facts
- Godot project lives in `project/`. Run all checks with `GODOT=/path/to/godot tools/check.sh`.
- Tests: dependency-free runner `project/tests/run_tests.gd` (base class `TestCase`). Add new suites to its `SUITES` list (an unlisted `*_test.gd` or one that does not parse fails the run). Focused run: `... -s res://tests/run_tests.gd -- --only=qa,options` — never edit SUITES for that.
- Tunable values live in `project/data/**.tres` Resources (`PlayerMovementConfig`, `CameraRigConfig`).
- Physics layers: 1 = world, 2 = player, 3 = climbable (put climbable walls on layers 1 + 3 and use `climb_stone.tres` so players can see them).
- Expedition flow (Phase 3): game boots to `scenes/ui/hunt_board.tscn`; `SceneFlow` injects the chosen `HuntDefinition` into the expedition scene's `Expedition` node (`ExpeditionManager`). Countdown logic is the pure `ExpeditionTimer`; rules in `data/expedition/default_expedition.tres` (never below 45:00 — a test enforces it). Test-only shorter timer: `-- --expedition-seconds=N`.
- Combat (Phase 4): `PlayerCombat` (+ `HealthComponent`, `Hitbox`/`Hurtbox`, `DamageInfo`); attacks are `AttackDefinition` resources slicing `Dual_Weapon_Combo`; enemies in `scripts/enemies/` (`Thornling`, `TrainingDummy`), lock-on via group `lock_targets`. Physics layers 4 = enemy, 5 = hitbox, 6 = hurtbox.
- Bosses (Phases 5, 8): every boss is `BossController` + data (`BossAttackDefinition.kind` FRONT/DASH/ERUPTIONS/RADIAL + node paths); `Kurogale` is an empty subclass. Bosses collide with the world only (never ride the player). Emberwild hazards live in `scripts/world/hazards/`; expedition scenes are `scenes/main/main.tscn` (Verdant) and `scenes/main/expedition_emberwild.tscn`. Earlier: `Kurogale` driven by `BossDefinition` data (attacks, parts, rewards, `ElementProfile`); every attack must telegraph (tests compare against the data, not the boss). Parts break and reward once (`ExpeditionManager.run_rewards`). Persistent materials: `PlayerProfile` (`user://profile.json`; tests set `PlayerProfile.path`).
- Crafting (Phase 7): `Forge` (pure rules) over `PlayerProfile` (v2: materials, gear_owned, equipped); data in `data/gear/` + `data/crafting/catalog.tres`; `GearLoadout` applies gear at expedition start; the dojo is `scenes/ui/hunt_board.tscn` (Hunt board + Forge tabs).
- Moonfen (Phase 9): `scenes/main/expedition_moonfen.tscn`, boss `nami` (data only). Movement-changing ground is `SurfaceZone` (speed multiplier / blocks_jump / current / damage tick) registered on `PlayerController`; `FogZone`, `SinkingRaft`; `LavaZone.element` (bog = water). Comfort options in `GameSettings` (`user://settings.cfg`; tests set `GameSettings.path`); warning shaders take a `boost` uniform. Generated nodes needing instance shader params use `InstanceTint`.
- Stormcrag (Phase 10): `scenes/main/expedition_stormcrag.tscn`, boss `raijins_echo`. `GustZone` extends `SurfaceZone` (periodic `current`, chevron "Warning" strips); `SurfaceZone.traction` = grip; `StormCaller` + `StormShelter` (lightning that targets where you stand); `RainFX` (CPU particles, fewer on LOW). Elements in use: fire, water, lightning, earth, nature, poison.
- Second beasts (Phase 13): `tools/generate_beasts.gd` (run AFTER `generate_visual_pass.gd`, which rewrites the biomes) writes kamakiri/kasai/gamakage/kazekiri data, scenes, items and hunts. `HuntDefinition.boss_scene` replaces the arena's `Level/Boss` at expedition start; `HuntDefinition.requires_hunt` gates it (`HuntBoard.is_hunt_open`).
- Slash trails: `WeaponTrail` (one per hand blade, made by `WeaponMount`; a fixed 32-point ArrayMesh built once, positioned by uniforms in `shaders/slash_trail.gdshader` — never rebuild geometry per frame: an ImmediateMesh version crashed the Godot app on Android) emits while `PlayerCombat.swing_active()` (lead/tail around the hit window, never for projectiles). Tuning in `data/combat/blade_trail.tres` (`TrailConfig`: lifetime, alpha, colours per blade element, smoothing; fewer subdivisions on LOW); per-attack `AttackDefinition.trail_width/trail_intensity` (heavy 1.3 / 1.35).
- Traversal lives in `TraversalComponent` (tuning: `data/player/traversal.tres`); checkpoints are `scenes/world/checkpoint.tscn`.
- World is procedural: `BiomeTerrain` (heightmap + collision), `FloraScatter`, `FaunaSpawner`, `BiomeAtmosphere`, driven by `project/data/biomes/*.tres`. Shaders in `project/shaders/` must stay `gl_compatibility`-safe (no screen/depth texture reads).
- Graphics presets (Phase 11): `QualityPreset` data in `data/quality/{low,medium,high}.tres`; `QualityProfile.tier()/current()` (command line `-- --quality=low|medium|high` or `-- --low-quality` > `GameSettings.quality` > auto: LOW on Android, HIGH on PC). `QualityProfile.apply_to_scene()` runs at expedition start (render scale, shadows, glow, light fade); world builders read the preset (flora density/draw distance, terrain mesh step, mist, rain, particles). New heavy features must read a preset field. Tests pin a tier with `QualityProfile.force_tier()`. Budgets + results: `docs/PERFORMANCE.md`; benchmark: `BenchmarkRunner` (dojo Settings tab) / `tools/benchmark.gd`.
- Audio (Phase 11): all sound is synthesized by `tools/generate_audio.gd` (original; regenerate any time) into `assets/audio/` + `data/audio/sound_bank.tres` (`SoundBank`/`SoundCue`). `AudioDirector` (created by `ExpeditionManager`) only listens to gameplay signals — gameplay code never calls audio. Buses: Master, Music, SFX, Ambience (`default_bus_layout.tres`); volumes in `GameSettings`. **Never use AudioStreamWAV loop modes** (the WAV loop wrap crashed the Godot app on the owner's Android phone — confirmed fixed by removing it): loops are `LOOP_DISABLED` and `AudioDirector` restarts them on `finished`.
- Release (Phase 12): `PlayerProfile` saves atomically (`.tmp` → rename, `.bak` backup, unreadable file → `.corrupt` + backup). Leaving/restarting/closing mid-hunt calls `ExpeditionManager.abandon()` (keeps gathered, no credit). Difficulty = `DifficultyPreset` data (`data/difficulty/`; never a timer field; telegraph multiplier ≥ 1). Remapping = `InputRemap` (primary binding per kind, swap on conflict, saved in settings.cfg `[remap]`) + `ControlsPanel`. Build: `export_presets.cfg`, `tools/build.sh`; docs `RELEASE_CHECKLIST.md`, `KNOWN_ISSUES.md`. Version in `project.godot` `config/version`. `GameSettings.brightness` (default 1.5, applied by `QualityProfile.apply_brightness`) and `GameSettings.unlock_all` (testing switch in the dojo; `HuntBoard.is_open` honours it) — tests that check locking must leave it off.
- Player model: `project/assets/models/ninja/ninja.glb` (Mixamo). Clip mapping in `data/player/ninja_animations.tres`. It has **no Idle clip** (a pose is generated). Combo = attacks, Quick_Roll_To_Run = dodge, Death_Backward = hurt/death, Climb_Up_Wall / Climb_Down_Wall = climbing (looped in place), Climb_On = hang pose (frame 0) + mantle (0–2.9 s slice fitted to `mantle_time`), Draw_Sword / Sheath_Sword = blades (action `draw_sword`; `PlayerCombat.sword_drawn`, timing in `PlayerCombatConfig`; `WeaponMount` shows hand or left-hip pair, sheath placed in the player frame and calibrated on the standing pose). Sprint_To_Wall_Climb = kick-up (0.5–1.83 s slice) when a climb starts at ≥ `wall_run_min_speed` (sprint), then the climb loop. Detrending anchors hips horizontally at the clip's frame 0. Blades are attached at runtime by `WeaponMount`: the grip is computed per hand from its own knuckles in the fist pose (never hard-coded offsets — the left hand is mirrored), and `HandGrip` BAKES the Dual_Weapon_Combo finger pose into every other clip at load (no runtime SkeletonModifier3D — a per-frame finger modifier was followed by crashes on the owner's Android phone; Godot's own empty PhysicalBoneSimulator3D is fine). Weapon clips (combo, draw, sheathe) keep their own hands.
- Crash diagnosis on device: `CrashReport` (session marker in user://, file logging on for all platforms; the dojo shows the previous session's log tail + Copy after a crash). Add `CrashReport.note()` breadcrumbs for new risky features; a 2 s heartbeat goes to `user://breadcrumbs.log`. Never set shader/material parameters every frame when the value has not changed (sky writes re-bake the sky — suspected Mali crash); Low has `sky_flash` and `sky_reflections` off. `ShaderWarmup` draws every distinct visual once at expedition load (paused, breadcrumb per step; skipped headless) — new visuals that appear only at runtime should exist (hidden) in the scene so the warm-up covers them.
- Scenes were produced by `tools/generate_phase1_scaffold.gd` then `tools/generate_visual_pass.gd`; re-running a generator overwrites hand edits.
- Concept art for the four jungles is in `docs/concept-art/` (reference only, not in-game assets):
  `verdant_canopy.jpg`, `emberwild.jpg`, `moonfen.jpg`, `stormcrag.jpg`.

## Agents
Use specialist agents when their work can be parallelized. Main agent owns integration and decisions. Read profiles in `.claude/agents/`. The `godot-*` agents and `.claude/rules/` come from Claude-Code-Game-Studios (MIT); see `docs/THIRD_PARTY.md`. Where they conflict with this file, this file wins (e.g. tests use our own runner, not gdUnit4, until the owner approves adding it).

## Skills
Read relevant skill files in `.claude/skills/` before major work. Skills are workflow guides, not commands to blindly execute.

## Phase discipline
Follow `docs/PHASES.md`. Do not skip phase gates. Phase 0 is planning and environment validation. Phase 1 is a minimal playable prototype. Content expansion waits for a stable vertical slice.
