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
