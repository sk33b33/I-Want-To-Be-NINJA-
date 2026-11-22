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
| 7–13 | Not started | — |

Note: at the owner's request a **visual pass** (gloomy Verdant Canopy, procedural terrain/flora/fauna, Mixamo ninja) was done ahead of Phase 6/11. It is placeholder-quality procedural art; it does not complete Phase 6 or Phase 11. 33/33 automated tests pass.

