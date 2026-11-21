# Architecture Plan

## Suggested project structure
```text
project/
  project.godot
  scenes/
    main/
    player/
    biomes/
    boss/
    ui/
    hub/
  scripts/
    player/
    camera/
    traversal/
    combat/
    hunt/
    boss/
    crafting/
    world/
    ui/
  data/
    biomes/
    bosses/
    items/
    recipes/
  assets/
    models/
    materials/
    textures/
    animations/
    audio/
    vfx/
  tests/
```

## Systems and ownership
- `GameState`: current mode, biome, selected hunt, run state.
- `ExpeditionTimer`: starts on expedition start, pauses in pause/settings, stops and emits event at boss arena entry.
- `PlayerController`: locomotion and input; keep camera-independent.
- `TraversalComponent`: climbable surfaces, ledge detection, jump/dodge; feature-gate advanced traversal.
- `CameraRig`: third-person and top-down modes, smooth switching, collision/occlusion.
- `CombatController`: attacks, dodge, lock-on, damage events.
- `ElementSystem`: affinity, weakness, resistance, status effects.
- `BossController`: boss state machine and attack selection.
- `PartDamageComponent`: part health, break event, reward.
- `HuntManager`: selected target, run lifecycle, boss gate.
- `CraftingManager`: recipes and inventory/material validation.
- `BiomeDefinition` / `BossDefinition`: Resource-based data definitions.

## Event signals
Prefer signals over direct cross-system references:
`expedition_started`, `boss_arena_entered`, `timer_expired`, `part_broken`, `boss_defeated`, `reward_granted`, `hunt_completed`.

## Data-driven content
Use Godot `Resource` definitions for biomes, bosses, elemental types, attack definitions, breakable parts, items, and recipes. Prototype with JSON only if it simplifies iteration; validate schemas.

## Performance / content pipeline
- Use mesh/material instancing and MultiMesh for grass/foliage.
- LOD and visibility ranges for distant trees/rocks.
- Collision only on gameplay-relevant surfaces.
- Keep VFX pools and cap particles.
- Profile before optimizing; record target PC specs and FPS goal.
- Use placeholder assets until art direction and licenses are approved.

## Test strategy
- Script/unit tests for timer state, element matchup, part-break rewards, and recipe requirements.
- Scene test for player movement/camera.
- Manual test matrix for biome obstacles and boss telegraphs.
- Headless Godot parse/import where available.
