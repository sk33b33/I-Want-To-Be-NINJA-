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
