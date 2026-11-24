# Phase Progression & Gates

**Never advance just because code was generated. Advance only when the acceptance gate passes.**

## Phase 0 — Project definition & setup
- Confirm Godot version, target platform (PC first), input, repo, project boot.
- Create clean project structure, CLAUDE.md, docs, asset ledger.
- **Gate:** project opens; one empty test scene runs; project conventions agreed.

## Phase 1 — Movement + camera prototype
- Third-person movement, run, jump, fall recovery.
- Camera collision and orbit.
- Switch to top-down camera smoothly.
- Graybox terrain and basic collision.
- **Gate:** 10-minute playtest; camera modes work; no stuck states in test route.

## Phase 2 — Traversal vertical slice
- Climbable wall detection and climb movement.
- Ledge grab/step-up (if stable); obstacle route with gaps, rocks and cliff.
- Checkpoint and respawn.
- **Gate:** complete a graybox route from spawn to gate in both camera modes.

## Phase 3 — Expedition flow & timer
- Biome/hunt selection stub.
- 45:00 countdown, pause handling, timeout behavior.
- Boss gate / arena entry event stops and hides timer.
- **Gate:** timer behavior tested at start, pause, resume, arena entry and timeout.

## Phase 4 — Combat foundation
- Light/heavy attack, dodge, lock-on, health and damage.
- Enemy hit reaction and player feedback.
- **Gate:** combat loop feels controllable and can be repeated without softlock.

## Phase 5 — First boss + part break
- One original boss with telegraphed attacks, elemental affinity/weakness.
- One breakable part, reward drop, victory state.
- **Gate:** boss can be defeated; part-break reward is granted once and recorded.

## Phase 6 — First biome vertical slice
- Verdant Canopy graybox-to-art pass, route, optional detour, checkpoint, boss arena.
- Target beast selection, one hunt.
- Basic HUD and results.
- **Gate:** complete one full expedition from selection to rewards with timer rules.

## Phase 7 — Crafting & progression
- Inventory/materials, 2–3 recipes, gear stats, upgrade feedback.
- Hub/dojo forge and hunt board placeholder.
- **Gate:** part rewards can craft and equip an item; persistence validated.

## Phase 8 — Biome 2: Emberwild
- Unique volcanic art, heat/lava obstacles, target boss and elemental matchup.
- Reuse proven systems; no duplicate architecture.
- **Gate:** distinct route hazards and complete hunt flow.

## Phase 9 — Biome 3: Moonfen
- Water/mud/poison/fog traversal and target boss.
- Readability/accessibility pass.
- **Gate:** distinct mechanics, complete hunt flow.

## Phase 10 — Biome 4: Stormcrag
- Mountain/cliff/wind/rain traversal and target boss.
- **Gate:** distinct mechanics, complete hunt flow.

## Phase 11 — Art, audio, optimization
- Replace placeholder assets with properly licensed assets or original content.
- Material/lighting/VFX polish, audio, LOD, foliage instancing, quality presets.
- Profile target hardware and fix worst bottlenecks.
- **Gate:** documented performance target met on agreed hardware; no missing asset licenses.

## Phase 12 — QA, accessibility, release preparation
- Save/load, settings, remapping, difficulty, bug pass, build pipeline.
- Test timer and hunt edge cases, camera, bosses, crafting, respawns.
- **Gate:** release checklist complete; known issues documented.

## Phase 13 — Optional expansion
- Additional beasts per biome, weapons, secrets, co-op, dynamic weather/day-night.
- Only after base game is stable and owner approves scope.

## Current status
Claude must update this section only after evidence of completed work.

| Phase | Status | Evidence |
|---|---|---|
| 0 — Setup | **Gate passed** (2026-11-21) | Godot 4.5.1 headless import clean; `scenes/tests/boot_test.tscn` prints `BOOT_OK`; conventions in `CLAUDE.md`. |
| 1 — Movement + camera | **Implemented, automated checks pass; gate NOT yet passed** | 19/19 headless tests (movement, jump, fall recovery, camera blend/collision, scripted run of the full graybox route). Gate still needs the **10-minute human playtest** on PC and on an Android phone. |
| 2 — Traversal vertical slice | **Implemented, automated checks pass; gate NOT yet passed** | Bot completes the Verdant Canopy route spawn → boss gate in **both** camera modes (climbs rampart, crosses gorge, grabs far-bank ledge, no falls). 42/42 tests incl. 7 traversal tests. Needs a human run of the route on PC and phone. |
| 3 — Expedition flow & timer | **Implemented, automated checks pass; gate NOT yet passed** | Hunt board → expedition; 45:00 countdown verified at start, pause, resume, arena entry (stops + hides, never restarts or expires) and timeout (results screen). 57/57 tests. Needs a human check of the flow on PC and phone. |
| 4 — Combat foundation | **Implemented, automated checks pass; gate NOT yet passed** | Light 3-hit combo, heavy, dodge i-frames, hurt/knockback, death → respawn at shrine, lock-on; Thornling enemy with telegraphed lunge + stagger; training dummy. Gate bots: beats two Thornlings without dying, and 15 s of random input never leaves the player stuck. 16 combat tests. Needs a human feel test on PC and phone. |
| 5 — First boss + part break | **Implemented, automated checks pass; gate NOT yet passed** | Kurogale (Nature, weak to Fire): antler sweep, root snare, charge (stuns on pillars), enraged thorn burst; every attack verified to warn before it can hurt. Antlers break once at 220 damage and reward once; victory grants Kurogale's Hide; rewards saved once to the player profile. Gate bot defeats Kurogale and breaks the antlers without dying. Needs a human fight on PC and phone. |
| 6 — First biome vertical slice | **Implemented, automated checks pass; gate NOT yet passed** | Gate bot plays one full expedition: hunt board → Verdant Canopy route (timer running, gathers on the way) → arena (timer stops + hides) → Kurogale defeated, antlers broken → results; materials saved. Optional detours (Thornling hollow, high bridge, gorge stones, far-bank top) hold gatherables; two lore stones; shrines heal; objective arrow/distance HUD; lighting lifted slightly per owner. The route pieces are still CSG blocks with procedural stone (no hand-made art). Needs a human run on PC and phone. |
| 7 — Crafting & progression | **Implemented, automated checks pass; gate NOT yet passed** | Dojo with Hunt board + Forge tabs; 3 recipes (Thornfang Blades, Barkhide Garb, Ember Charm) with readable stats; forging consumes materials once; equip per slot; gear applied at expedition start (blade tint, HUD line). Gate test: antler from a won hunt → forged → equipped → profile reloaded from disk → in effect next expedition. Old (v1) saves still load. Needs a human pass through the dojo on PC and phone. |
| 8 — Biome 2: Emberwild | **Implemented, automated checks pass; gate NOT yet passed** | Volcanic biome with distinct hazards (fire-vent wave, heat zone + cool lane, sinking stones over a lava river, crumbling basalt shortcut, lava that burns and returns you to a shrine) and the Ashen Oni-Tortoise (fire; weak to water; horns break once). Bosses now run on one data-driven `BossController` (Kurogale refactored onto it, all its tests still pass). Mist Charm (water talisman) + 2 Emberwild recipes. Unlocks after Kurogale (`-- --unlock-all` for testing). Gate bot: crosses Emberwild without touching lava, defeats the Tortoise with the Mist Charm, rewards saved. 125/125 tests. Needs a human run on PC and phone. |
| 9 — Biome 3: Moonfen | **Implemented, automated checks pass; gate NOT yet passed** | Violet bioluminescent swamp with mechanics not seen before: mud flats (slow, no jumping; a fallen-log bypass), a stream current that drifts you toward a poison pool, poison pools (damage over time), a fog bank that closes in (spirit lanterns mark the safe line, poison hides off it), reed rafts that sink under your weight over a deep bog that drowns you back to the shrine, then a root-wall climb. Nami, the Lantern Serpent (water/spirit; weak to lightning; lantern breaks once). Storm Charm (lightning talisman, forged from Emberwild materials) + 2 Moonfen recipes; Moonfen unlocks after the Tortoise. **Readability/accessibility pass:** screen-shake toggle, bold attack warnings (brighter fill, thicker rims on every telegraph), talisman HUD named/coloured by element, each swamp hazard has its own colour (brown mud, green poison with a rim, violet bog). Gate bot: crosses Moonfen without sinking, defeats Nami with the Storm Charm, rewards saved. 145/145 tests. Needs a human run on PC and phone. |
| 10 — Biome 4: Stormcrag | **Implemented, automated checks pass; gate NOT yet passed** | Storm-mountain biome with mechanics not seen before: a climbable cliff up to a storm plateau where lightning picks the spot you stand on (ring warning → bolt; keep moving, dodge, or shelter under rock overhangs), then a narrow rain-slick ridge over a chasm with wind gusts that warn with chevrons and alternate sides; constant rain (CPU particles, a quarter of the drops on phones) and frequent lightning flashes; a stepped storm temple on the skyline. Raijin's Echo, the Sky Roc (lightning; weak to earth; crest breaks once). Stone Charm (earth talisman, forged from earlier materials) + 2 Stormcrag recipes; Stormcrag unlocks after Nami — all four jungles are now in the game. Gate bot: climbs the cliff, crosses the storm plateau and the gale ridge without being blown off, defeats the Sky Roc with the Stone Charm, rewards saved. 159/159 tests. Needs a human run on PC and phone. |
| 11 — Art, audio, optimization | **Implemented, budgets met; gate NOT yet passed** | Owner chose original content only and a target of 30 fps on a mid-range phone (Low) / 60 fps on PC (High). **Optimization:** data-driven Low/Medium/High presets (render scale, shadows, glow, flora density/draw distance, coarser terrain render mesh, light fade, mist, rain, particles) with Auto/pause-menu/dojo selection; measured with a new benchmark — Low now draws 106k–169k triangles and 163–218 draw calls at its worst viewpoints (was up to 434k / 280), all three presets inside their budgets (`docs/PERFORMANCE.md`). **Audio:** 24 sound effects, 4 biome ambience loops, exploration music, boss taiko drums and a victory sting, all synthesized by our own `tools/generate_audio.gd`; an `AudioDirector` plays them from gameplay signals (every boss telegraph has a warning chime); Master/Music/SFX volume sliders. **Polish:** landing/roll dust, preset-scaled hit sparks, a dojo Settings tab. No missing licenses (ledger updated). Gate needs the owner to run **Settings → Run benchmark** on their phone and confirm 30 fps. 172/172 tests. |
| 12 — QA, accessibility, release prep | **Implemented, checklist complete except owner items; gate NOT yet passed** | QA pass with 14 edge-case tests that found 6 real bugs, all fixed (a damaged save wiped all progress; saves were not crash-safe; a save with wrong field types crashed loading; quitting or restarting mid-hunt lost gathered materials; switching apps let the 45:00 countdown run on). Control remapping (keyboard/mouse + gamepad, swap on conflict, persists, reset), Easy/Normal/Hard as data (never touches the timer; warnings never shorter), touch button size, auto-pause, original app icon, version 0.12.0, export presets (Android/Windows/Linux), `tools/build.sh` (exported game verified to boot and run an expedition). `docs/RELEASE_CHECKLIST.md` and `docs/KNOWN_ISSUES.md` written. Owner items left: export templates/Android SDK/keystore for installable builds, package name, phone benchmark, human playtest. 195/195 tests. |
| 13 — Optional expansion | **In progress** — owner scope: second beast per jungle ✅, more weapons ✅, secrets & exploration, day/night & weather (co-op not now) | Part 1: four new beasts (Kamakiri, Kasai, Gamakage, Kazekiri), one per jungle, unlocked after that jungle's first beast; all data-driven on `BossController`; every attack telegraphs; parts break and reward once; gate bot defeats each. 233/233 tests. Part 2: four weapon types (Mantis Kama, Cinder Claws, Venom Tanto, Gale Greatblades) forged from those beasts' parts — different speed/reach/stagger/blade and a trait (part breaking, poison); balanced within 15% damage×speed; the gate bot defeats Kurogale with each. Needs a human feel test on PC and phone. |

Note: at the owner's request a **visual pass** (gloomy Verdant Canopy, procedural terrain/flora/fauna, Mixamo ninja) was done ahead of Phase 6/11. It is placeholder-quality procedural art; it does not complete Phase 6 or Phase 11. 33/33 automated tests pass.

