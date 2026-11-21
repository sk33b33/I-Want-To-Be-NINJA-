# Game Design Document (GDD)

## High concept
A ninja hunter explores four distinct magical jungle regions in a sandbox-style 3D world. Each expedition is a timed traversal challenge leading to one boss arena. The player chooses which elemental beast to hunt, learns its weaknesses, survives its unique terrain, and breaks beast parts to forge gear.

## Platforms
Android phones and PC (Windows/Linux) from one Godot project. Phones use on-screen touch controls; PC uses keyboard/mouse or a gamepad. Design every mechanic so it can be played with a thumb joystick and a few big buttons (no precision mouse-only actions). Performance budget is set by mid-range Android phones.

## Concept art (owner-supplied mood references)
| Biome | Reference | Key takeaways |
|---|---|---|
| Verdant Canopy | `docs/concept-art/verdant_canopy.jpg` | Overgrown stone ruins and towers wrapped in roots, tiered waterfalls into a turquoise pool, warm sun shafts, glowing teal/orange fungi. |
| Emberwild | `docs/concept-art/emberwild.jpg` | Jagged black spires, a lake of cracked lava, red-orange glow through smoke, a lush jungle edge with waterfalls framing the view. |
| Moonfen | `docs/concept-art/moonfen.jpg` | Night swamp in violet/indigo, magenta and cyan bioluminescent plants, glowing pools along a dark stream, hanging vines, giant mushroom silhouette. |
| Stormcrag | `docs/concept-art/stormcrag.jpg` | Stepped temple pyramid in the mountains, lightning storm overhead, many waterfalls and terraced fields, turquoise river, inhabited and festive. |

These are mood references only (licenses unknown — see `assets/ASSET_LEDGER.md`).

## Pillars
1. **Ninja traversal** — agile running, jumping, climbing, wall traversal, ledge grabs, grappling/rope traversal only after core movement is reliable.
2. **Readable hunts** — clear boss telegraphs, elemental identity, meaningful weaknesses and part damage.
3. **Exploration sandbox** — branching routes, optional caches, shortcuts, secrets, environmental puzzles.
4. **Progression through trophies** — broken parts become materials, unlock recipes, and visibly change gear.
5. **Beautiful atmosphere** — layered jungle foliage, wet surfaces, mist, waterfalls, strong silhouettes, dynamic skies, and elemental VFX without sacrificing gameplay readability.

## Run structure
- Choose a biome.
- Select a target beast from the biome hunt board.
- Load into an expedition with a **45:00 countdown** (design target; timer may be configurable in testing).
- Traverse the biome and its obstacle route. Optional side paths reward supplies, lore, or crafting resources.
- Reach the boss gate/arena. Trigger an explicit `BossArenaEntered` event: hide expedition timer and stop it permanently for that run.
- Fight the selected boss; discover/ exploit elemental weaknesses; damage and break specific parts.
- Receive rewards based on victory and broken parts.
- Return to hub, craft or upgrade weapons/armor, and unlock hunts.

## Camera
- **Third-person:** default, behind/over-shoulder with camera collision, sensitivity and inversion settings.
- **Top-down:** alternate camera with adjustable zoom, pitch, and target framing. Camera transition should be smooth; both modes support combat and traversal.
- Keep boss, hazards, ledges, and interactables visible. Camera mode is a player option, not a separate game mode.

## Biomes and traversal identity
### 1. Verdant Canopy
Dense tropical forest, vines, giant roots, canopy bridges, vertical trees, moving platforms, branch routes.
Obstacle set: vine swing (later), climbable bark/walls, root maze, branch balance, leap gaps, canopy shortcuts.
Visuals: sun shafts, green canopy layers, leaf particles, humid haze, streams.

### 2. Emberwild
Volcanic jungle with black rock, ash, lava fissures, scorched plants, heat shimmer.
Obstacle set: timed stepping stones, heat zones, collapsing basalt, lava gaps, vent bursts, fire-resistant route choices.
Visuals: ember particles, orange-red lighting, smoke, lava glow, dark foliage.

### 3. Moonfen
Bioluminescent swamp with shallow water, mud, floating roots, fog and luminous plants.
Obstacle set: sinking mud, submerged paths, poison pools, water-current crossings, unstable platforms, fog navigation.
Visuals: cyan/violet glow, reflections, mist, floating spores.

### 4. Stormcrag
Mountain jungle, cliff faces, waterfalls, high winds, cloud bridges and storm-lit ridges.
Obstacle set: climbing walls, wind gust timing, exposed ledges, rockfall, waterfall routes, cliff jumps.
Visuals: dramatic cloud layers, lightning, rain, distant peaks, wind-driven vegetation.

Each biome has a route layout with at least one main path, optional detours, checkpoints, shortcuts, and a boss entrance. Reuse traversal systems with biome-specific hazards and level dressing.

## Boss roster concept
Create original creatures and spiritual entities. The first prototype should use **one** boss, not all.

| Biome | Hunt target | Element | Weakness | Signature |
|---|---|---|---|---|
| Verdant Canopy | Kurogale, the Thornback Stag | Nature | Fire | Root snare, antler sweep |
| Emberwild | Ashen Oni-Tortoise | Fire | Water | Shell slam, lava burst |
| Moonfen | Nami, the Lantern Serpent | Water/Spirit | Lightning | Flood wave, illusion |
| Stormcrag | Raijin's Echo, Sky Roc | Lightning | Earth | Dive, wind shear |

These are working names and concepts; revise freely. Myth-inspired entities must be original reinterpretations, not copied depictions.

## Boss mechanics
- Bosses have phase/state machines: idle, telegraph, attack, recovery, stagger, enraged, part-broken, defeated.
- Attack tells must be visible and audible with generous prototype timings.
- Elemental affinity affects damage/status and environmental interactions.
- Parts have independent health thresholds, hit zones, and reward definitions.
- Prototype part breaks: one part (e.g., horn, tail, shell) with clear visual feedback and reward drop.
- Avoid unavoidable damage; each attack needs a readable counter (dodge, jump, block, position, or elemental tool).

## Combat
Prototype: light attack, heavy attack, dodge, lock-on, elemental tool/skill, damage/stagger feedback.
Later: weapon classes (katana, dual blades, spear, kusarigama, bow, staff), combos, parry, stamina, elemental build options.
Combat should be animation-driven where possible; prototype hitboxes may be simple shapes.

## Crafting / part economy
Boss part rewards: horns, scales, claws, cores, membranes, fangs, essence. Parts map to recipes. Crafting is initially a small menu with 2–3 recipes. Gear stats should be understandable (damage, defense, element, traversal utility), not opaque grind.

## Sandbox systems
- Optional collectibles and lore shrines.
- Resource gathering (prototype: a few pickups).
- Checkpoints and shortcut unlocks.
- Hub / dojo: hunt board, forge, training area.
- Future: day/night, weather variation, co-op only if scope and architecture allow.

## Timer rules
- HUD shows `MM:SS` (45:00 initially) during expedition.
- Timer counts down only while expedition is active and player is not in pause/settings.
- On arena entry: stop timer, hide UI, store elapsed/remaining run time for results.
- Timer expiration: prototype returns player to checkpoint or ends expedition with a clear message; decide exact penalty during Phase 1. Do not make boss timer expire.
- The minimum design requirement is **45 minutes per run**; do not shorten it for production gameplay without owner approval.

## Visual quality targets
- Crisp silhouettes, coherent stylized-realistic art direction, readable terrain, foliage variation, layered backgrounds and skies.
- PBR materials for wet mud, water, bark, moss, stone, metal, and elemental surfaces.
- Vegetation density via instancing; avoid individually expensive objects.
- Post-processing used tastefully: color grading, fog, bloom for magic, SSAO/SSIL where performant.
- VFX must have clear shapes, timing, and elemental colors; don't obscure boss tells.
- Provide scalable presets (Low/Medium/High) and test target hardware before promising fidelity.

## Accessibility / usability
- Remappable controls, camera sensitivity, invert Y, camera mode toggle.
- Adjustable HUD size, colorblind-friendly telegraphs, subtitles, reduced camera shake, difficulty options.
- Pause/settings should not consume expedition timer.
