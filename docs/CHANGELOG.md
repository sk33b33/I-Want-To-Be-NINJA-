# Changelog

- Kit created. No game implementation has been completed yet.

## 2026-11-21 — Phase 0 + Phase 1 prototype
- Kit installed into the repo; Godot 4.5.1 validated headless. Phase 0 gate passed.
- Added Godot specialist agents and rules from Claude-Code-Game-Studios (MIT, see `docs/THIRD_PARTY.md`).
- Platforms set to Android phone + PC. Renderer `gl_compatibility`, ETC2/ASTC textures, landscape orientation, Jolt physics.
- Input map for keyboard/mouse, gamepad, and on-screen touch controls (joystick, look-drag, JUMP/DASH/CAM).
- `PlayerController`: camera-relative run/sprint, jump with coyote time, jump buffer and variable height, fall recovery to last safe ground.
- `CameraRig`: third-person orbit with spring-arm wall collision; smooth blend to an adjustable top-down camera.
- Verdant Canopy graybox route: steps, ramp/ledge, camera wall, tunnel, stream, 3 pit gaps, future boss-gate clearing.
- Debug HUD, headless test runner with 19 tests, `tools/check.sh`.
- Concept art for the four jungles saved to `docs/concept-art/`.
- Placeholder primitives only — no final art.

## 2026-11-21 — Visual pass: gloomy Verdant Canopy + Mixamo ninja
Owner feedback: wanted more landscape, more flora and fauna, more detailed terrain, darker/ominous mood, and the owner's Mixamo ninja.
- Player now uses `assets/models/ninja/ninja.glb` with `NinjaAnimator`: Idle (generated pose), Run, Sprint, Jump, and Front_Flip for sprint-jumps. Root motion stripped from jump clips. Faint ground ring + readability light keep the dark ninja visible.
- Sculpted procedural terrain (`BiomeTerrain`): hills, valley walls, border cliffs, a stream, and a map-wide gorge under the pit jumps; matching HeightMap collision. Route corridor kept flat so traversal is unchanged.
- Procedural flora (`FloraScatter`): giant buttress-root jungle trees with hanging vines, dead twisted trees with grey moss, grass, ferns, broad-leaf plants, glowing mushrooms (teal/orange/violet), mossy rocks, fallen logs, broken ruin pillars. Chunked MultiMeshes with draw distances.
- Fauna (`FaunaSpawner`): circling bat flocks, frogs that hop away from the player, glowing lurker eyes that watch and vanish when approached, firefly swarms.
- Atmosphere (`BiomeAtmosphere`): storm-dusk sky shader with distant lightning flicker, cold moonlight, ground mist, faint light shafts, dark water, two waterfalls into the gorge, rune-lit boss gate.
- `QualityProfile`: phones automatically use a LOW tier (fewer plants, shorter draw distances, one shadow cascade, half the mist). Preview on PC with `-- --low-quality`.
- Tests: 33 (was 19) — terrain, flora, fauna and animation suites added.
- All art is still placeholder-quality procedural geometry, not final assets.

## 2026-11-21 — Phase 2: traversal vertical slice
- `TraversalComponent` (child "Traversal" of the player): wall climbing on the new physics layer 3 "climbable", climb over the top (auto mantle), ledge grab on any solid ledge, ledge shimmy, pull-up, drop, wall jump. No new buttons: everything works the same on touch, gamepad and keyboard.
- Climbable surfaces use `climb_stone.tres` (carved handholds with a faint teal glow) so they read in the dark.
- `Checkpoint` shrines (`scenes/world/checkpoint.tscn`): spirit flame turns from red to teal; falls respawn at the latest lit shrine (spawn counts as the first).
- Route: climbable rampart across the path, optional high route (raised ledge → broken bridge with a jump → rampart top), far-bank wall over the gorge that must be ledge-grabbed, boulders, three shrines.
- Animator: CLIMB / HANG / MANTLE states using stand-in clips (Crouch_Walk, Jump poses) until real Mixamo climbing clips are added.
- Tests: 42 (was 33). Phase 2 gate bot run passes in third-person and top-down.

## 2026-11-22 — Phase 3: expedition flow & timer
- Game now opens on the **hunt board** (`scenes/ui/hunt_board.tscn`): four jungles from `data/biomes/biome_*.tres`; Verdant Canopy / Kurogale playable, the others locked until Phases 8–10.
- `ExpeditionManager` + pure `ExpeditionTimer`: 45:00 countdown (`data/expedition/default_expedition.tres`, never below 45 min; test-only override `-- --expedition-seconds=N`, shown as "debug timer").
- HUD timer (top centre): amber under 5:00, red pulsing under 1:00, "PAUSED" while paused, hidden for good on boss-arena entry.
- Pause menu (Esc / Start / touch II button): freezes game and timer; Resume, Restart expedition, Back to hunt board.
- Boss arena behind the rune gate: ruin ring and red sigil (boss arrives in Phase 5); entry trigger covers the whole arena so any way in counts.
- Timeout: expedition ends with a results screen (Retry / Hunt board). Decision recorded in the GDD; configurable.
- Chosen hunt is injected into the expedition scene by `SceneFlow` (no global state singleton).
- Debug overlay moved to bottom centre so it never covers the timer.
- Tests: 57 (was 42).

## 2026-11-22 — Phase 4: combat foundation
- Combat building blocks: `HealthComponent`, `DamageInfo`, `Hitbox` (layer 5) / `Hurtbox` (layer 6) with teams; attacks are data (`data/combat/attack_*.tres`) slicing the owner's Mixamo clips at measured strike times.
- `PlayerCombat`: 3-hit light combo, heavy attack, dodge roll with i-frames (keyboard: tap Shift or C), hit-stun with knockback, death (Death_Backward) → respawn at the last shrine with full health (the expedition timer keeps running), lock-on with camera tracking and strafing, hit-stop + light camera shake.
- Twin procedural blades attached to the ninja's hands at runtime (`WeaponMount`).
- **Thornling** (original small beast): wander → chase → telegraph (rears up, spines glow red, chevron ground strip) → lunge → punishable recovery; poise/stagger; leash; health bar; two live in a hollow west of the tunnel.
- **Training dummy** at the spawn clearing (never dies, shows damage).
- Feedback: pooled sparks + damage numbers (`CombatFx`), player health bar with damage trail, red hurt flash, "Defeated" message, lock-on reticle.
- Touch controls: ATK / HVY / ROLL / LOCK buttons; CAM moved to the top-right.
- Tests: 16 new combat tests incl. two gate bots.

## 2026-11-22 — Phase 5: first boss — Kurogale, the Thornback Stag
- Data-driven boss: `BossDefinition` / `BossAttackDefinition` / `BossPartDefinition` (`data/bosses/kurogale.tres`), per-creature `ElementProfile` (fire ×1.5, earth ×0.5).
- Kurogale (`scripts/bosses/kurogale.gd`, procedural stag with thorned back and branching antlers): dormant until the arena event, roaring intro, stalk, four telegraphed attacks — Antler Sweep (red arc), Root Snare (green rings under the player), Charge (long red strip; stunned if it hits a pillar), Thorn Burst (enraged only, red ring). Enrages at 50% (20% faster tempo). Head lowers during recoveries/staggers so the antlers can be struck.
- Breakable antlers (220 part damage): break once → long stagger, antlers snap to stubs, weaker sweep, +1 Thornback Antler (granted once per run).
- One swing touching body and antlers counts as one hit (lands on the part).
- **Ember Talisman** player skill (F / RB / FIRE button): fire projectile, 4 s cooldown.
- Victory: "Hunt complete" results (time, parts broken, materials). Rewards written once to `user://profile.json` (`PlayerProfile`); the hunt board lists earned materials.
- Boss HUD: name, health bar, part status, enrage / part-broken banners. Arena sigil recoloured violet (red now always means danger).
- Tests: 16 boss tests incl. the gate bot (defeats Kurogale, breaks antlers, no deaths).

## 2026-11-22 — Fix: attack, roll and climb animations did not play
- Reported by the owner: attacks and the dodge roll showed no animation although they worked.
- Cause: `NinjaAnimator._ready()` runs before the player's own `_ready()` (children first), so `player.combat` / `player.traversal` were still null and the animator never connected to them. Attack (Dual_Weapon_Combo slices), roll (Quick_Roll_To_Run), hurt/death and the Phase 2 climb/hang/mantle animations were all silently skipped.
- Fix: the animator looks the components up directly on the player.
- Regression tests (seen failing before the fix): light, heavy, roll and climb each check the AnimationPlayer's current clip. 93/93 tests pass.

## 2026-11-22 — Phase 6: Verdant Canopy vertical slice
- Lighting lifted slightly at the owner's request (ambient 3.5 → 4.3, exposure 1.35 → 1.5, moon 1.2 → 1.35, lighter fog); still dark and moody (mean screen brightness ~20 → ~31 / 255).
- Gatherables (`Pickup`): Glowcap (Thornling hollow ×3, high route ×2, gorge stone, far-bank wall top) and Ruin Shard (behind the ruin wall, by the gorge waterfall). Collected once; kept even if the beast escapes; saved to the profile.
- Two lore stones (`LoreStone`): "The Drowned Way" (spawn) and "Of Kurogale" (gate clearing, a fight hint). Text shown once on the HUD.
- Shrines heal the hunter to full the first time they are lit.
- HUD: objective arrow + distance to the arena under the timer; "+1 item" pickup note.
- Results: time to spare at the arena; on escape, lists what you gathered and kept.
- Hunt credit (`hunts_completed`) only for a defeated beast.
- Tests: `biome_slice_test.gd` (7) incl. the gate — one full expedition from the hunt board to saved rewards; bots moved to `tests/bot_helpers.gd`.

## 2026-11-22 — Phase 7: crafting & progression
- Data: `GearDefinition` (weapon/armor/charm + readable stats), `RecipeDefinition`, `CraftingCatalog` (`data/gear/`, `data/crafting/`).
- Recipes: **Thornfang Blades** (Thornback Antler + Ruin Shard → blade damage +25%, thorn-green blades), **Barkhide Garb** (Kurogale's Hide + 2 Glowcap → +25 max health, 15% less damage), **Ember Charm** (3 Glowcap + Ruin Shard → talisman cooldown −1.5 s, damage +30%).
- `Forge` rules: craft only when all materials are owned; consumes them exactly once; each gear forged once; equip owned gear per slot.
- Dojo hub (placeholder, UI-based): the hunt board gains Hunt board / Forge tabs, an "Equipped:" summary, and a forge panel with have/need costs, stat lines, Forge/Equip buttons and a "Forged!" flash.
- `GearLoadout` applies equipped gear at expedition start (damage, health, armor, talisman); HUD shows the loadout.
- `PlayerProfile` v2: `gear_owned`, `equipped`; v1 saves still load.
- Tests: `crafting_test.gd` (11) incl. the gate.

## 2026-11-22 — Phase 8: Emberwild + Ashen Oni-Tortoise
- **Boss refactor:** `BossController` runs any boss from data. `BossAttackDefinition.kind` = FRONT / DASH / ERUPTIONS / RADIAL plus the scene nodes, pose, glow and part-weakening it uses; parts declare their intact/broken visuals. `Kurogale` is now an empty subclass (all Phase 5 tests unchanged and passing).
- **Emberwild** (`scenes/main/expedition_emberwild.tscn`): ash/basalt terrain, scorched flora, ember-glow mushrooms, rising embers, ember sky, lava river and lavafalls, basalt route pieces with glowing veins.
- **Hazards** (`scripts/world/hazards/`): `FireVent` (dormant → warning → erupt; four in a wave), `HeatZone` (burns over time; cool lane alongside), `SinkingStone` (up → warning → sink → rise), `CrumblePlatform` (breaks after you step on it, reforms), `LavaZone` (burns + back to the last shrine).
- **Ashen Oni-Tortoise** (fire; ×1.5 water, ×0.25 fire): Shell Slam, Lava Burst, Shell Spin (homing; stuns on pillars), enraged Ember Field. Breakable horns → Oni Horn; victory → Ashen Shell Plate.
- **Progression:** Emberwild unlocks after defeating Kurogale (`BiomeDefinition.requires_hunt`; `-- --unlock-all` for testing). New forge items: **Mist Charm** (talisman becomes water — the counter to the Tortoise), **Oni Fang Blades** (+40%, fire blades — strong vs Kurogale), **Ashen Plate** (+40 HP, −25% damage). New gatherable: Ember Crystal. Gear can now set blade / talisman elements.
- **Bug fixes found by the new tests:** bosses could land on the player and ride along (the player counted as a moving floor) — bosses now collide with the world only and never use the player (or each other) as a platform; test runner now lets physics settle between tests.
- Tests: `emberwild_test.gd` (13) incl. the gate, boss regression test; 125 total. Also hardened three older tests: the light-combo test now locks on and presses inside the combo window (it relied on exact frame timing), the timeout test waits physics frames (render frames do not pace real time headless), and two tests updated for Phase 8 content (6 recipes; Emberwild gated by Kurogale).

## 2026-11-22 — Fix: touching the screen made the ninja attack (phones)
- Android emulates a left mouse click from every touch, and left mouse is the light attack, so touching the joystick to start moving swung the blades. `PlayerCombat` now ignores emulated mouse events (`DEVICE_ID_EMULATION`); a real mouse still attacks on PC.
- Regression test `combat_test.gd::test_touching_the_screen_does_not_attack` (seen failing before the fix). Suite: 126 tests, 0 failed.

## 2026-11-22 — Phase 9: Moonfen + Nami, the Lantern Serpent; readability pass
- **Moonfen** (`scenes/main/expedition_moonfen.tscn`): violet night sky, bioluminescent flora, frogs and spirit motes, dark violet bog water.
- **New mechanics** (`scripts/world/hazards/`): `SurfaceZone` — ground that changes movement while you stand in it (mud: x0.45 speed and no jumping; stream: sideways current; poison pools: damage over time). `PlayerController` asks its active zones for speed, jump and drift, so it never needs to know what the ground is. `FogZone` thickens the world fog inside a bank and clears after; spirit lanterns mark the safe line. `SinkingRaft` sinks under your weight (your weight is the clock — unlike Emberwild's timed stones) and floats back up. `LavaZone` now takes an element, so the deep bog drowns (water) instead of burning.
- **Nami, the Lantern Serpent** (water/spirit; lightning x1.5, water/fire x0.5): Flood Wave (long strip), Lantern Lure (spirit spouts under you), Dive Strike (stuns on pillars), enraged Spirit Rain. The brow lantern breaks → Lantern Pearl; victory → Nami's Scale. Same `BossController`, data only.
- **Forge:** Storm Charm (lightning talisman; Ember Crystal x3 + Ruin Shard — craftable before Moonfen), Moonfang Blades (+35%, water — good vs the Tortoise), Fenscale Mail (+30 HP, −20% damage). New gatherable: Spirit Moss. Moonfen unlocks after the Ashen Oni-Tortoise.
- **Readability / accessibility pass:** pause menu options **Screen shake On/Off** and **Bold attack warnings On/Off** (saved in `user://settings.cfg`, `GameSettings`); the talisman HUD line names and colours the current element (Ember / Mist / Storm Talisman); every swamp hazard has its own colour and the poison pools a warning rim.
- **Bugs found by the new tests:** the bold-warnings option was lost when a warning material dropped out of Godot's resource cache between scenes (fixed: every expedition and the dojo re-apply it when they start); generated spirit-lantern flames lost their colour (instance shader parameters are not saved by the generator; new `InstanceTint`). `tools/check.sh` now fails if any SCRIPT ERROR is printed during tests — a script error aborts a test early, which otherwise reads as a pass.
- Tests: `moonfen_test.gd` (14) incl. the gate, `accessibility_test.gd` (5). 145 total.

## 2026-11-22 — Phase 10: Stormcrag + Raijin's Echo, the Sky Roc
- **Stormcrag** (`scenes/main/expedition_stormcrag.tscn`): grey-blue storm sky with near-constant lightning, wind-bent grass, crag stone, rain (`RainFX`, CPU particles following the camera; 1400 drops on PC, 300 on phones), a stepped storm temple on the skyline (scenery).
- **New mechanics** (`scripts/world/hazards/`): `StormCaller` — while you stand in the open on the storm plateau, lightning targets your spot every 2.6 s: a pale ring warns for 1.2 s, then the bolt falls (keep moving, roll through, or shelter). `StormShelter` — rock overhangs the storm never strikes under. `GustZone` (a `SurfaceZone`) — calm → chevron warning that shows the wind's direction → gust that pushes you sideways; alternates sides. `SurfaceZone.traction` — rain-slick stone (0.35 grip) on the gale ridge: you speed up and stop slowly. Plus a climbable cliff to start the route.
- **Raijin's Echo, the Sky Roc** (lightning; earth x1.5, lightning x0.25, water x0.75): Wing Shear (wide front), Storm Call (bolts in circles around you), Thunder Dive (stuns on pillars), enraged Thunder Burst. The crest breaks → Storm Crest; victory → Roc Plume. Wings beat slowly (creature shader). Data only on `BossController`.
- **Forge:** Stone Charm (earth talisman; Ruin Shard x2 + Spirit Moss x2), Thunderfang Blades (+45%, lightning — good vs Nami), Galeweave Garb (+45 HP, −25% damage). New gatherable: Storm Glass. Talisman HUD now also names the Stone Talisman. Stormcrag unlocks after Nami.
- The gust and lightning warning materials are included in the Bold attack warnings option.
- Tests: `stormcrag_test.gd` (14) incl. the gate. A probe confirmed that walking into a gust blows the hunter off the ridge, so the gate's "never blown off" check means something. 159 total.

## 2026-11-22 — Phase 11: optimization, audio, polish
- **Owner decisions:** original content only (no downloaded packs); performance target 30 fps on a mid-range phone on Low, 60 fps on PC on High.
- **Quality presets** (`QualityPreset`, `data/quality/low|medium|high.tres`; `QualityProfile.tier()/current()/apply_to_scene()`): render scale, moon shadows and cascades, glow, flora density and draw distance, terrain render-mesh step (collision keeps full detail), light fade distance, mist, rain, particle counts, lightning flash lights. Auto = Low on Android / High on PC; choose in the dojo **Settings** tab or the pause menu (applies from the next expedition); `-- --quality=<tier>` on the command line.
- **Benchmark:** `BenchmarkRunner` tours spawn / mid-route / arena in all four jungles and reports fps, draw calls and triangles against the target — dojo **Settings → Run benchmark** (runs on the phone; saves `benchmark.txt`) and `tools/benchmark.gd`. Results and budgets in `docs/PERFORMANCE.md`: Low's worst viewpoint went from 434k triangles / 280 draw calls to 169k / 218.
- **Audio** (all original, synthesized by `tools/generate_audio.gd`; logged in `assets/ASSET_LEDGER.md`): 24 effects (blade swings, hits, roll, jump/land, footsteps, talisman, hurt, death, boss roar/impacts/eruptions, part-break crack, a rising warning chime on every telegraph, shrine bell, pickup chime, lightning, gusts, vents, bog splash, timer warnings at 5:00 and 1:00), an ambience loop per jungle (night insects; magma rumble and crackle; frogs and drips; rain and wind), a koto-and-drone exploration theme, boss taiko drums and a victory sting. `AudioDirector` plays them purely from gameplay signals; buses Master/Music/SFX/Ambience with volume sliders (`GameSettings`, saved).
- **Polish:** dust puffs on landing and rolling; hit spark counts follow the preset.
- **Fixes found on the way:** the benchmark tool never started its run (hung) — found before release; audio players now release their sounds when a scene closes.
- Tests: `quality_test.gd` (5), `audio_test.gd` (6), `settings_benchmark_test.gd` (2); stormcrag rain test updated to the preset. 172 total.

## 2026-11-22 — Phase 12: QA, accessibility, release preparation (v0.12.0)
- **QA pass** (`qa_test.gd`, 14 edge-case tests; each fix seen failing first):
  - a damaged/torn save loaded as empty and the next save overwrote it — all progress lost. Saves are now atomic (`.tmp` → rename), the previous good save is kept as `.bak`, and an unreadable file is set aside as `.corrupt` while the backup loads;
  - a save with wrong field types crashed loading — every field is now type-checked;
  - quitting to the dojo, restarting or closing the game mid-hunt lost the gathered materials — now kept exactly like an escape (`ExpeditionManager.abandon()`, no hunt credit);
  - switching to another app let the 45:00 countdown run — the pause menu now opens on focus loss / app pause.
  - Verified (no change needed): arena entry after a timeout, dying in the arena, lock-on after a kill, a boss killed mid-telegraph, top-down camera across respawns, old saves with removed gear, mud/climb state after respawn.
- **Control remapping** (`InputRemap`, dojo Settings → Controls): keyboard/mouse and gamepad per action, conflicts swap, saved in `settings.cfg`, reset to defaults; a damaged entry never unbinds an action; screen touches are never taken as mouse clicks.
- **Difficulty** Easy/Normal/Hard (`DifficultyPreset`, `data/difficulty/`): damage taken, boss health, boss warning time (Easy +30%, never shorter). No timer field — 45:00 on every difficulty (test).
- **Accessibility:** touch button size (0.8–1.4×, spacing grows with it, stays on screen), touch talisman button renamed CHARM.
- **Release:** version 0.12.0, original app icon, `export_presets.cfg` (Android arm64 / Windows / Linux; tests excluded), `tools/build.sh` (checks → data-pack export for every preset → boots the exported game; installable builds when templates/SDK/keystore exist, otherwise lists what is missing). `docs/RELEASE_CHECKLIST.md`, `docs/KNOWN_ISSUES.md`.
- Test runner: every `tests/*_test.gd` must be listed (a missing suite fails the run — a focused run had nearly committed a cut-down suite list); focused runs use `-- --only=qa,options` instead of editing the file.
- Tests: `qa_test.gd` (14), `options_test.gd` (9). 195 total.

## 2026-11-23 — Owner's model update: real climbing animations
- `ninja.glb` replaced with the owner's new Mixamo export: same character and skeleton, the original 9 clips unchanged, plus **Climb_Up_Wall**, **Climb_Down_Wall** and **Climb_On**.
- Climbing now plays Climb_Up_Wall going up/sideways and Climb_Down_Wall going down (paused when holding still, faster when climbing fast); hanging holds Climb_On's first frame (hands on the ledge); the mantle plays Climb_On's pull-up (0–2.9 s) fitted to the existing 0.45 s mantle — gameplay timing unchanged. The stand-ins (Crouch_Walk / Jump frames) are gone.
- The clips' root motion (the climb rises 1.1 m per cycle; the pull-up 1.9 m up and 3.7 m forward) is removed at load with a straight-line "detrend" that keeps each reach and the heave, so they loop in place on the body that TraversalComponent moves.
- Test runner hardening: a suite file that does not parse now fails the run (it counted as 0 tests before).
- Tests: animator suite updated (12 clips, up/down/pause, in-place loops, hang + mantle fit); seen failing against the old model first.

## 2026-11-23 — Draw / sheathe blades (owner's Draw_Sword + Sheath_Sword clips)
- `ninja.glb` updated again: adds **Draw_Sword**, **Sheath_Sword** (and Sprint_To_Wall_Climb, not used yet); everything else unchanged.
- New action **Draw / sheathe** — R / D-pad ↑ / touch **BLADE** (top right); remappable (Settings → Controls).
- Both blades go to a sheath at the left hip (the clips draw across the body from the left hip) and come back to the hands at the moment the hand reaches the hip in each clip (`PlayerCombatConfig`: draw 0.8 s, swap at 0.05 s; sheathe 1.2 s, swap at 0.85 s).
- Never in the way: standing still plays the full animation; moving keeps running while the blades change place on time; a roll completes it instantly; attacking while sheathed draws and attacks in one press; an attack during the first part of a sheathe cancels it. Expeditions start with blades drawn (no change for existing play).
- Placement bug found by screenshot: the sheath was first computed from the hip bone's rest pose and ended up in front of the body pointing sideways; it is now set in the player's frame and calibrated on the live standing pose (test checks left side, hip height, pointing back and down).
- Tests: `blades_test.gd` (8); animator clip list updated to 14. 205 total.

## 2026-11-23 — Sprint_To_Wall_Climb kick-up
- Reaching a climbable wall at sprint speed (≥ 9 m/s, `NinjaAnimationConfig.wall_run_min_speed`) plays the kick-up part of the owner's **Sprint_To_Wall_Climb** (0.5–1.83 s; the run-up before it already happened in game) at 1.4×, then hands over to the climb loop; climbing down cancels it. A normal run still goes straight into the climb.
- Bug found by screenshot: removing the clip's root motion anchored the hips where they are at the start of the slice — 1.9 m ahead after the run-up — so the ninja was drawn inside the wall. Hips are now anchored horizontally at the clip's first frame (over the feet); a test checks it.
- Tests: animator suite +3 (sprint kick-up, no kick-up from a run, kick-up in place).

## 2026-11-23 — Fix: blades not held properly (owner playtest)
- Owner report after playing to the boss: "the swords are not placed properly in the hands when unsheathed". Close-ups showed three faults: both hands used the same grip offset although the left hand's bone axes are mirrored (the left blade stuck out of the palm and up the forearm); the handle crossed an open hand 4–5 cm from where fingers would close; and the hands were open because the movement clips were animated without weapons.
- `HandGrip` (SkeletonModifier3D) closes both hands while the blades are drawn, using the finger pose of the owner's Dual_Weapon_Combo clip (fingers ~70° curled); sheathed hands stay relaxed.
- `WeaponMount` computes each hand's grip from that hand's own knuckles in the fist pose: the handle runs across the knuckles through the closed fingers and the blade leaves on the thumb side — correct for both hands without per-side numbers.
- Tests: `grip_test.gd` (3) — fingers closed, handle inside each fist (< 3.5 cm), blade out of the thumb side for both hands, relaxed when sheathed; seen failing on the old code first.

## 2026-11-23 — Slash trails for light and heavy attacks (owner request)
- `WeaponTrail`: a fading ribbon from each blade's guard to its tip, drawn during the swing of light and heavy attacks (from just before the hit frame to just after the hit window — not during the wind-up, never for the talisman). Smoothed between frames (cubic), fades over 0.16 s, additive and translucent.
- Heavy attack trail is wider (band runs further down the blade) and brighter; colour follows the forged blade element (fire orange, water blue, lightning pale, earth amber), plain steel-blue otherwise.
- Data: `data/combat/blade_trail.tres` (`TrailConfig`) and `AttackDefinition.trail_width / trail_intensity` (heavy set in the generator too). LOW quality uses less smoothing.
- First look was a near-opaque white sheet (additive + scene glow): toned down to a translucent streak, brightest at the tip.
- Tests: `trail_test.gd` (4).

## 2026-11-23 — Fix: Godot crashed on Android a few seconds into light attacks
- Owner report (Godot app on an Android phone; system notice "Godot Engine 4 is crashing frequently"). The crash began with the slash trails, which rebuilt their ribbon geometry every frame (ImmediateMesh: fresh GPU buffers every frame) — a pattern mobile GLES3 drivers handle badly. Desktop could not reproduce it.
- The trail mesh is now a fixed 32-point strip built once; each frame only shader uniforms change (`shaders/slash_trail.gdshader` positions the vertices). Looks the same.
- While verifying in the real renderer: unused trail points collapsed to the world origin and drew a streak to the ground — they now collapse onto the last real point.
- Regression test: the trail mesh is the same object with the same fixed vertex count after repeated swings (failed on the old trail). Needs the owner's retest on the phone to confirm the crash is gone.

## 2026-11-23 — Android crash, round 2: remove the per-frame finger modifier; crash reports
- The owner's screen recording showed the Godot app closing ~8 s into an expedition **while only walking** (no attacks) — so not the slash trail (hidden when not attacking). The only other change since the owner's crash-free run to the boss was the grip fix's `HandGrip`, a SkeletonModifier3D rewriting 30 finger bones every frame.
- `HandGrip` no longer runs at runtime: the fist is baked into the clips' finger tracks once at load (weapon clips keep their own hands). Trade-off: the hands are also closed while the blades are sheathed. Grips, fists and blade placement are unchanged.
- **Crash reports:** Godot's log file is now written on phones too; a session marker detects a crash, and the next launch shows the end of the previous session's log in the dojo with **Copy report** (backgrounded apps closed by the OS do not count as crashes). Breadcrumbs: session start (version, device, quality), expedition start, arena entry.
- Tests: grip suite — no game-added skeleton modifier, fist baked into Run/Sprint/Climb/Idle (failed on the modifier version); `crash_report_test.gd` (4). End-to-end: a killed session is reported on the next launch with its log tail.
- Still needs the owner's retest on the phone; if it crashes again, the dojo report (Copy) is what to send.

## 2026-11-23 — Android crash, round 3: the sky was re-baked every frame
- The owner's first crash report (Galaxy S20 SM-G980F, Mali-G77, OpenGL ES 3.2 driver r38p1, Low quality) showed the log simply stopping after "expedition kurogale" — a native (driver/engine) crash, and with the round-2 build, so the finger modifier was not the cause.
- Found: `BiomeAtmosphere` wrote the sky shader's `flash` parameter **every frame** (120 writes in 120 frames, in every jungle since the visual pass). Each sky-material change makes the renderer re-bake the sky; the first lightning flash is scheduled 5 s into every expedition — matching both crashes. Heavy per-frame GPU work like this is a classic trigger for Mali driver crashes.
- Fix: the sky is written only when the flash value changes; on Low (phones) the sky stays still and lightning flashes through the moonlight only (`QualityPreset.sky_flash`), and sky reflections are off (`QualityPreset.sky_reflections`: no radiance cubemap at all). Medium/High keep the full effect. Side effect: the Low benchmark on the software renderer went from 8–10 fps to 11–16 fps at the same viewpoints.
- Crash reports now include the session's last moments: a 2-second heartbeat (fps, memory, position, animation, combat/traversal state, blades, timer, boss state) and event notes (e.g. lightning flashes), written to their own always-flushed file so they survive a native crash.
- Tests: `sky_test.gd` (3; the every-frame rewrite fails it), crash-report breadcrumbs test. Needs the owner's retest on the phone.

## 2026-11-23 — Android crash, round 4: shader warm-up with per-step breadcrumbs
- Owner's second crash report (with heartbeats): the ninja stood **idle at spawn** (40 fps, 108 MB, boss asleep), a lightning flash with the sky kept still passed harmlessly, and the app died ~8–10 s into the expedition with nothing happening — the same timing as the screen recording. So: not input, not the sky, not memory.
- Leading suspect: a native crash in the Mali driver while **compiling a shader the first time something comes into view** (bats circling in, fireflies, eyes appearing) — compatibility-renderer shaders compile on first draw.
- `ShaderWarmup`: when an expedition loads, every distinct visual (31 in the Verdant Canopy: terrain, foliage, mushrooms, bats, frogs, fireflies, water, mist, shrine flame, warnings, health bars, boss…) is drawn once, one per frame, behind a "Preparing the jungle…" screen with the game paused (the 45:00 countdown does not run). Each step is written to the crash breadcrumbs **before** it is drawn, so if the phone crashes the report names the exact material and shader. Also removes mid-game shader-compile stutters. Real renderer: 31 visuals in ~2–3 s on the software renderer.
- Heartbeat every 1 s (was 2 s); 80 breadcrumbs kept.
- Tests: `warmup_test.gd` (every visual drawn and logged, hidden things re-hidden, camera restored, unpaused, countdown unchanged).

## 2026-11-23 — Android crash, round 5: the 8-second ambience loop
- Owner's third report: the shader warm-up completed all 31 visuals without a crash (so not shaders), then the app died ~7.7 s later while attacking. Across all three crashes the constant is **8 seconds of hunt audio**: the jungle ambience is an 8.0 s loop, and the crash comes when it first wraps (report 1: audio from 8.1 s → crash 15.8–17.8 s; report 2: audio from 6.7 s + 1.1 s paused for the warm-up → crash just after 15.9 s; the screen recording: ~8 s).
- No stream uses the engine's WAV looping any more (`tools/generate_audio.gd` writes `LOOP_DISABLED`); `AudioDirector` restarts ambience and music itself when they finish (`finished` signal; never after victory/timeout), with a breadcrumb per restart. Verified in real time: 3 restarts in 19 s (ambience at 8 s and 16 s, music at 16 s).
- Test: no stream in the sound bank uses WAV looping (failed on the old files); ambience and music restart when they end. Needs the owner's retest.

## 2026-11-23 — Android crash confirmed fixed
- Owner retest on the Galaxy S20: **no more crashes**. Confirmed cause: the engine's WAV loop wrap at the end of the 8 s ambience loop (round 5). The earlier rounds' changes are kept as phone hardening and diagnostics (static trail geometry, baked fists, sky written only on change and still on Low, shader warm-up, crash reports with breadcrumbs).

## 2026-11-23 — Brighter by default + brightness setting; unlock all jungles for testing
- Owner: "still a bit too dark". New **Brightness** slider (Settings, dojo and pause menu; 0.8–2.0×, live) scaling each jungle's exposure and ambient light; default **1.5×** (compared on Low at 1.0 / 1.5 / 1.8 — 1.5 shows the ground, ninja and props and still reads moody; 1.8 starts to wash out). `QualityProfile.apply_brightness()` remembers the level's own values so the slider never compounds.
- Owner: "make the other jungles available so I can test". New dojo switch **Unlock all jungles (testing)** (saved; off by default) — the hunt board refreshes with all four hunts open. The normal unlock chain is unchanged when it is off.
- Tests: `brightness_unlock_test.gd` (2). 228 total.

## 2026-11-23 — Phase 13, part 1: a second beast in every jungle
Owner approved Phase 13 scope: second beast per jungle → more weapons → secrets & exploration → day/night & weather (no co-op for now).
- Four new original beasts, each its own hunt on the board, unlocked by beating that jungle's first beast (or the **Unlock all** testing switch):
  - **Kamakiri, the Ironbark Mantis** (Verdant Canopy; nature, weak to fire) — Scythe Cross, Leaping Strike, Seed Burst, Whirling Scythes; the scythes break.
  - **Kasai, the Cinder Salamander** (Emberwild; fire, weak to water) — Flame Breath, Belly Slide, Magma Spit, Cinder Ring; the tail breaks (get behind it).
  - **Gamakage, the Bog Toad** (Moonfen; water/poison, weak to lightning) — Tongue Lash, Belly Flop, Venom Bubbles, Croak Shock; the throat sac breaks.
  - **Kazekiri, the Gale Wolf** (Stormcrag; lightning, weak to earth) — Gale Claw, Thunder Lunge, Storm Howl, Static Burst; the storm fangs break.
- Each drops a part material (Mantis Scythe, Cinder Tail, Toxin Sac, Gale Fang) and a victory hide; they are in the forge catalog, ready for the new weapons in part 2.
- Beasts are pure data + a generated scene on the existing `BossController` (no new boss code): `tools/generate_beasts.gd` writes boss data, scenes, materials, items and hunts. `HuntDefinition.boss_scene` swaps the beast into the jungle's arena; `HuntDefinition.requires_hunt` + `HuntBoard.is_hunt_open()` gate it.
- Bodies are procedural primitives (placeholder art, original designs).
- Tests: `beasts_test.gd` (5) — complete data, every attack warns before it can hurt, the hunt puts its beast in the arena and the part rewards once, unlock order, and a gate bot that defeats each new beast (bringing the talisman for its weakness). 233 tests total, all passing.
- Bug found by screenshot, fixed: swapping in the new beast with `Node.replace_by()` carried the jungle's first boss's body, hurtboxes and hitboxes along on the new beast (Kasai wore the Tortoise's horns). The old boss is now freed before the beast takes its place; the arena test checks the beast has only its own nodes (failed before the fix).

## 2026-11-23 — Art pass, stage 1: ground & rocks (CC0 textures, painterly)
Owner chose: free CC0 assets + code, stylized painterly look, all areas (ground & rocks → trees & plants → lighting & mood → beasts), phones kept at 30 fps on Low.
- Five CC0 texture sets from ambientCG (forest floor, mud path, cliff rock, stone blocks, bark; colour + normal map, ~2.7 MB total, VRAM-compressed with mipmaps), recorded in `assets/ASSET_LEDGER.md`.
- Painterly use: the textures give the **detail** (twigs, leaf litter, cracks, block joints) while each jungle's palette gives the **colour**, so the four jungles share one small texture set and keep their own look. Each texture's 1×1 mip is its average colour, used to keep brightness under the palette's control.
- Terrain (`terrain.gdshader`): textured ground cover, trodden path and triplanar rock on slopes. Route stone, ruins and climb walls (`stone`), basalt (`basalt`), reed rafts, scattered boulders, tree bark and wooden route pieces (new `painted.gdshader`) all get triplanar texture detail (`include/textured_triplanar.gdshaderinc`).
- Quality: normal maps and the anti-tiling sample are global shader uniforms (`detail_normals`, `anti_tile`, project.godot `[shader_globals]`) set once per expedition from `QualityPreset` — **off on Low**. Texture choice per material: `Cc0Surfaces` (used by `tools/generate_visual_pass.gd`; `tools/apply_cc0_textures.gd` patches existing materials).
- Reviewed with before/after screenshots in all four jungles (High and Low); stone walls and basalt toned down after the first round (the old noise pattern fought the texture).
- Tests: `art_test.gd` (4).

## 2026-11-23 — Art pass, stage 2: trees & plants
- **Leafy canopies:** a leaf-spray sprite composited from CC0 ambientCG leaves (`tools/art/leaf_cluster.py`, ledger) on crossed leaf cards around every canopy core (`leaf_card.gdshader`, alpha-tested, same wind sway, tinted per jungle) — Medium/High only (`QualityPreset.leaf_cards`). The cards use their own random stream, so a tree is identical with or without them.
- **All tiers (no extra geometry):** canopy cores carry the leaf-spray texture as detail; broadleaf plants have veins (midrib + side veins drawn from new blade UVs) and darker edges; every plant is darker at its base and varies slowly in colour across the jungle; tree bark texture is stronger.
- Benchmark: all presets inside their triangle/draw budgets (Medium Verdant tight: 583k of 600k); Low software-renderer frame time rose with the extra texture reads — see `docs/PERFORMANCE.md`; needs the owner's phone check.
- Tests: `art_test.gd` +3 (cards only add a surface and never change the tree; Low has none, High has them; every jungle's canopy has leaf detail and veins).

## 2026-11-23 — Art pass, stage 3: lighting & mood
- **`JungleMood`** (one per jungle in `data/mood/`, written by `tools/generate_moods.gd`, hand-tunable) applied once at load by `BiomeAtmosphere`: sun/moon colour and strength, ambient, exposure, **height fog that pools in valleys with a glow towards the sun**, saturation/contrast, a **split-tone colour grade** (shadows and highlights tinted separately; Environment colour-correction curve, verified on the compatibility renderer; off on Low via `QualityPreset.color_grade_lut`), light shafts (colour, strength, width) and stream water colour. Graded toward the concept art:
  - Verdant Canopy: golden back-light in teal mist, wider golden light shafts, turquoise water (was cool blue-grey, desaturated).
  - Emberwild: ash-grey haze, orange light.
  - Moonfen: deep blue with **bioluminescent foliage** — leaf veins and the brightest canopy leaves glow cyan and magenta (`foliage.gdshader`/`leaf_card.gdshader` `glow_color`, `glow_color_b`).
  - Stormcrag: slate storm light, full saturation (was 0.75), turquoise water.
- Moonfen's wooden route walls a little lighter (they read as black).
- The brightness slider scales each mood's exposure/ambient (unchanged behaviour).
- Bug found and fixed while reviewing screenshots: the first version put `mood` before `script` in the scene files, so Godot dropped it and nothing changed. `art_test.gd` now checks every jungle's sun, fog, saturation, grade (off on Low) and brightness come from its mood (watched failing on the old order).

## 2026-11-24 — Art pass, stage 4: beasts
- **Smoother bodies:** all eight beasts rebuilt with `ProceduralMeshes.smooth_level = 2` (`tools/rebuild_beast_meshes.gd`): twice the segments, curved tubes resampled along a spline, and lumps from low-frequency noise instead of per-vertex randomness. Same shapes, sizes, hitboxes and hurtboxes; each beast stays under ~4k triangles (one on screen at a time). Flora/fauna are unaffected (smooth mode is off at runtime).
- **Skins** (`creature.gdshader`, painterly: texture = detail, beast colour = colour), projected in the beast's own space so they move with the body: bark (Kurogale, Kamakiri), stone (Oni-Tortoise shell), scales (Nami, Kasai — new CC0 Leather008), hide (Raijin's Echo, Gamakage, Kazekiri — new CC0 Leather030). Normal maps only off Low.
- **Glowing markings** along each beast's back in its element colour: a slow pulse at rest that **flares during attack telegraphs** (an extra warning; the existing warnings are unchanged).
- **Rim light** in each beast's colour and a lighter back / darker belly, so silhouettes read against the dark jungle.
- Small fauna (bats, frogs, moths) keep their plain look (all new options default off).
- Tests: `art_test.gd` +2 (every beast has skin/markings/rim, fauna unchanged; beast bodies are the smooth rebuild within a 6k-triangle budget and smooth mode is off at runtime). 243 tests, all passing.

## 2026-11-24 — Phase 13, part 2: more weapons
Four new weapon **types**, one forged from each second beast's part (+ its hide + a gatherable from that jungle). The ninja has one set of weapon animations, so types differ by feel — swing speed, damage per hit, stagger, reach (hitbox size), blade shape, slash-trail length — and one trait. Damage × speed stays within 15% of the twin katana (a test enforces it): the choice is play style and the beast's weakness, not raw power.
| Weapon | From | Plays like | Trait / element |
|---|---|---|---|
| **Mantis Kama** (twin sickles) | Kamakiri's scythe | katana speed, a bit more reach | breaks beast parts 60% sooner; nature |
| **Cinder Claws** | Kasai's tail | 35% faster, short reach, light hits | fire |
| **Venom Tanto** | Gamakage's sac | 15% faster, short | poison: 6 damage/s for 5 s after each hit (refreshes, never stacks; scaled by the beast's poison resistance) |
| **Gale Greatblades** | Kazekiri's fangs | 22% slower, long reach, heavy | +70% stagger; lightning |
- Data: `WeaponType` (`data/weapons/`) on `GearDefinition.weapon_type`; written by `tools/generate_weapons.gd` (gear, recipes, catalog). Weapons without a type (the four earlier blades) are twin katana as before.
- `PlayerCombat.set_weapon_type()` builds adjusted copies of the combo once per expedition (the shared attack data is never changed) and scales the weapon hitbox; `WeaponMount.set_weapon_type()` swaps both hand blades and the sheathed pair to the new shape and fits the slash trails to its length. New blade meshes in `ProceduralMeshes` (`kama_blade`, `claw_blade`, `venom_tanto`, `gale_greatblade`) share the katana's handle so the grip stays right.
- Traits: `DamageInfo.part_multiplier` (counted towards part breaks), `DamageInfo.poison_*` → `HealthComponent.poison()`.
- The forge lists each weapon's type, how it plays and its numbers.
- Bug found by the new test and fixed: the slash trails are created a few frames after the expedition equips the weapon, so they kept the katana's length; the mount now fits each trail as it is created (watched the test fail first).
- Tests: `weapons_test.gd` (6) incl. the gate: the bot defeats Kurogale with each new weapon.

## 2026-11-24 — Phase 13, part 3: secrets & exploration
- **Hidden spirit shrines:** three per jungle (12), off the route on safe ground: **climb shrines** (a carved climbable pillar with the relic on top) and **hidden nooks** (a relic inside a ring of boulders with one narrow gap). A **spirit beam** rises from every unfound relic above the canopy so you can spot one from the path and go after it; it goes out once found.
- **Rewards:** each relic gives a **Spirit Relic** (saved the moment you find it — kept even if the hunt is abandoned or the beast escapes; never twice). Finding all three in a jungle grants its **Shrine Blessing: +10 max health, permanently** (Blessing of the Canopy / Ember / Fen / Storm — up to +40). Five relics forge the **Spirit Charm** (talisman cooldown −1.5 s, talisman damage +15%, +10 max health).
- **Hints and progress:** the pause menu shows "Spirit shrines x / 3" and a riddle for each one still missing; the hunt board shows each jungle's shrine count and blessing. A shrine bell and a banner announce each find, and the blessing when a jungle is complete.
- Data-driven: `SecretSet` / `SecretDefinition` (`data/secrets/<jungle>.tres`, written by `tools/generate_secrets.gd`), placed by `SecretSpots` (one per jungle scene) as `SecretSite`s. Saved in `PlayerProfile.secrets_found` (profile v3; older saves load). Flora keeps trees, logs and ruins clear of shrines.
- Found by the new tests and fixed before shipping: the first nook rings had boulders too big for the gap (no way in), tree trunks stood on three shrines, and one pillar overlapped Moonfen's arena wall; the spirit beams were too faint to spot.
- Tests: `secrets_test.gd` (5), incl. the gate: a bot starting on the route reaches and takes all 12 relics using only the controls (walking through nook gaps, climbing pillars).

## 2026-11-24 — Phase 13, part 4: day/night & weather
- **Time of day per expedition:** Day, Dawn, Dusk or Night — sun height, direction and colour, ambient light, fog colour and sky tint, layered on each jungle's mood. Every time stays readable (night is blue moonlight, not darker).
- **Weather per expedition:** Clear, Mist (thick valley fog), Rain (rain, wet shiny ground and stone, stronger wind in the plants), Storm (heavier rain and wind, much more frequent lightning), and Emberwild's Ash haze (no rain on the lava jungle). Each jungle has its own weighted table (`data/conditions/<jungle>.tres`): Verdant mixed, Emberwild ash, Moonfen mostly misty nights, Stormcrag mostly rain and storm.
- **The weather can turn mid-hunt** (rain rolling in over Verdant/Moonfen, a storm over Stormcrag, ash over Emberwild): fog, wetness and wind change in 10 steps over ~30 s (one step on Low), rain starts; a banner announces it. The sky is never touched during a hunt (phone crash rule).
- **Forecast** on every hunt-board card ("Forecast: Dusk · Rain (may turn to Storm)"); that forecast is exactly the expedition you get, and a new one is rolled for the next visit. The expedition's start banner repeats it.
- **Setting:** "Time & weather: Varied / Always clear day" (dojo and pause menu; applies from the next expedition).
- Everything is applied once at load by `ConditionsDirector` (created by `ExpeditionManager` before the shader warm-up; rain that may arrive later is created hidden so the warm-up covers it). Wet ground and wind are global shader uniforms (`wetness`, `wind_boost`), reset every expedition. Expeditions without a forecast (tests, benchmark) keep the plain mood.
- Bug found by the new tests and fixed: the director overwrote its own record of the wetness/wind it had just set.
- Tests: `conditions_test.gd` (6) — data/readability, no forecast = no change, dusk + rain really applies (sun, fog, rain, wet ground, brightness), the sky is tinted once and never compounds across hunts, the turn takes exactly 10 steps (1 on Low) without touching the sky, board forecast = expedition weather, "Always clear day".

## 2026-11-24 — Longer, harder routes in every jungle (owner request)
Owner: "the path to the bosses is too small, it goes too quick — extend it, longer and harder to navigate, for all stages". Chose ~3x longer; harder platforming, enemies on the path, branching paths and more hazards.
- **~370 m from spawn to the beast in every jungle (was ~120 m):** two new sections before each original route, which keeps all its coordinates (gorges, arenas, shrines, tests). The spawn moves to z = 250.
- **Section 1 — the fork:** a **safe but long** path (marked by lanterns) with an **enemy pack** and the jungle's **hazard lane** (thorn brambles / fire vents / poison pools / wind and lightning), or a **risky but short** path across a chasm on the jungle's platforms (crumbling stones / sinking stones / sinking rafts / rain-slick slabs in a gust), with a pickup at the far side.
- **Section 2 — the gauntlet:** a checkpoint, a **24 m chasm** with two crossings (narrow wooden beams, or the jungle's hazard platforms; lava below in Emberwild, deep bog in Moonfen), a **climb** to a plateau with a **hazard field** and an **enemy pack** (lightning with rock shelters in Stormcrag), a **dead-end arm** with a reward, a drop, a final enemy pack and a checkpoint before the original route. Emberwild and Stormcrag are mirrored (safe path on the other side).
- Fair by design: Emberwild's sinking stones rise and sink as a **travelling wave** (start on a fresh stone and ride it); Stormcrag's wind covers just two slabs, so you wait for a calm on the slab before it; every gap is a running jump (~2–2.5 m on the stepping lines).
- **Bug found and fixed:** the player body is created at the scene origin, inside the original spawn's checkpoint shrine, before it is moved to the new spawn — that stale overlap lit the shrine, so any fall on the new route returned you near the end of it (skipping it). Shrines now only take a player really standing in them (regression test watched failing first).
- Data-driven: `RouteLayout` / `RoutePiece` (`data/routes/<jungle>.tres`, written by `tools/generate_routes.gd`, which also extends the terrain — length, corridor segments incl. the fork, chasm `pits`, flat clearings — and adds a `RouteBuilder` to each jungle scene). `RouteBuilder` builds the pieces at load from existing hazard scenes/scripts, in each jungle's materials, and moves the spawn. Flora counts scale with the larger area (trees capped at 1.6x for phones); no trees in chasms or on the plateau.
- Tests: `routes_test.gd` (5) — length/forks/enemies/hazards, chasms carved and tree-free, a fall returns to the chasm's checkpoint, the start lights no shrine, and the gate: a bot walks **both** the safe and the risky way in every jungle from the new spawn to the original route without falling (navigation only — immune to damage). Every existing full-hunt gate bot now walks the new sections first, so the earlier gates cover the whole 3x route.
- **Faster tests (owner request):** the full check took over an hour once every hunt bot walked the 3x routes. Hunt bots now start where the original route starts (`BotHelpers.run_long_route` teleports there, without a respawn signal) unless a test sets `BotHelpers.walk_full_long_route`; `routes_test` walks the whole route (both ways, every jungle) and everything else runs as fast as before: the full check is ~47 min (265 tests).
- **Bot fixes found along the way** (test-only): a climb reads the raw stick (back = down), so after a lock-on fight left the camera facing away, "forward into the wall" climbed down — bots now point the camera along each leg; a fall resumes from the checkpoint's side of the path; a blocked-on-the-ground rule jumps; the bot's own dodge rolls were switching the test's invulnerability off (routes test uses a zero damage multiplier); plain walking bots no longer fight.
- **Performance regression found by the benchmark and fixed** (see `docs/PERFORMANCE.md`): the bigger terrain pushed Low (Verdant 257k) and Medium/High over their triangle budgets. Trees are never culled, so Low/Medium keep the original tree count (`QualityPreset.tree_area_growth`), and Medium/High render the terrain on a 2 m grid. All tiers are back inside their budgets.
- **Exploit found in the owner's play log and fixed:** the first chasm was only 20 m wide, so the hill beside it was walkable; the log shows the player running straight down the middle between the two branches (x 0..3, z 209 -> 155) and skipping the whole fork (enemy pack, hazard lane, chasm). The chasm now runs from the safe lane's edge to the map edge (`PIT1` in `tools/generate_routes.gd`), so the only ways on are the safe lane or the stepping pieces (`routes_test`: no walkable gap at any x; watched failing first). Also from that log: the phone at Low ran the long route at 40-58 fps, 134-141 MB (see `docs/PERFORMANCE.md`).


## 2026-11-25 — Graphics update, stage 5A (Verdant trees)
- Seven CC0 jungle tree models (OpenGameArt, ledger) replace the procedural jungle trees in the Verdant Canopy; lighter variants on Low (cap 1200 tris), more on Medium/High. Trunk collision measured from the model. Triangles after: Low 162k, Medium 513k, High 1.05M (budgets hold).
- New `model_foliage.gdshader` (atlas, tint, height-weighted sway, storm wind). Art test added; leaf-card test now uses Moonfen.
- Stage 5B groundwork: dev-only `tools/art/convert_dae.py` (needs `pip install trimesh pycollada numpy`; not a game dependency) converts the CC0 ruins pack (Godot can't import DAE) to Y-up GLB; 12 ruin models imported in `assets/models/cc0/ruins/`.
