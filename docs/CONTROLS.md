# Controls (prototype defaults)

Implemented in Phase 1: move, camera, jump, sprint (dash-run), switch camera, pause (frees the mouse).
Not yet implemented: dodge, attacks, lock-on, interact.

| Action | Keyboard | Controller | Phone (touch) |
|---|---|---|---|
| Move | WASD | Left stick | Left side: floating joystick |
| Camera | Mouse | Right stick | Right side: drag |
| Jump | Space | A / Cross | JUMP button |
| Sprint (dash-run, hold) | Shift | Left-stick click | DASH button |
| Sprint-jump (front flip) | Shift + Space | L3 + A | DASH + JUMP |
| Dodge | Shift (tap, planned) | B / Circle | — (Phase 4) |
| Light attack | Left mouse | X / Square | — (Phase 4) |
| Heavy attack | Right mouse | Y / Triangle | — (Phase 4) |
| Lock-on | Q | Right-stick click | — (Phase 4) |
| Interact | E | X / Square (context-sensitive) | — (later) |
| Switch camera | V | D-pad down | CAM button |
| Pause | Esc | Menu | — (Phase 3) |

These are defaults only. Implement remapping in a later phase. Avoid conflicting context actions.

Notes:
- Mouse look: click the game window to capture the mouse; Esc releases it. Mouse wheel zooms in top-down mode.
- Touch controls appear automatically on touchscreens. To test them on a PC, run with `-- --touch` (mouse emulates touch).
- Sprint and the future dodge share Shift: dodge will be a *tap*, sprint a *hold*. Revisit in Phase 4.
