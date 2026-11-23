# Known issues — v0.12.0

## Not final / placeholder
- **Art is procedural placeholder**, not final: route pieces are CSG blocks, bosses are low-poly procedural meshes, enemies are one reused Thornling design in every jungle. Only the ninja is a real model (owner's Mixamo character).
- **One hunt per jungle** (four beasts total). More beasts per biome are Phase 13 scope.
- Audio is synthesized placeholder-quality: functional and original, not composed/recorded.
- English only.

## Not yet verified
- **No human playtest** has passed any phase gate yet (Phases 1–12 are verified by automated tests and bots only). See the manual checklist in `docs/RELEASE_CHECKLIST.md`.
- **Phone frame rate unmeasured** on real hardware (budgets are met; run the in-game benchmark).
- **No installable build produced yet**: export templates, Android SDK/JDK and a keystore are not on the build machine. The exported game data is verified to boot.

## Design limits
- Touch controls are a fixed layout (size is adjustable; positions are not remappable).
- Remapping changes each action's *primary* key and gamepad button; extra defaults stay (arrow keys move, Q + middle mouse lock on).
- Difficulty scales player damage taken, boss health and boss warning time; Thornling health is the same on every difficulty.
- A single save profile (no slots, no cloud sync).
- The keyboard "tap Shift to roll" shortcut follows whatever key is bound to Sprint.

## Watch on device
- Android crash a few seconds into an expedition (2026-11-23): slash-trail geometry made static, the per-frame finger modifier replaced by baked clips, and the sky no longer re-baked every frame (no sky flash / reflections on Low); awaiting confirmation on the owner's phone. If it recurs, the dojo shows a crash report to copy.

## Cosmetic / engine
- Quitting while a sound is still playing prints "resources still in use at exit" in the console (engine shutdown message; no effect on players or saves).
- On a very slow device the first frames of an expedition hitch while the world is generated (terrain and flora are built at load).
