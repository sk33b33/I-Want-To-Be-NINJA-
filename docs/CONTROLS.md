# Controls (prototype defaults)

Implemented in Phase 1: move, camera, jump, sprint (dash-run), switch camera, pause (frees the mouse).
Implemented in Phase 2: climbing, ledge grab, mantle, wall jump — all automatic, no extra buttons (see "Traversal" below).
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

## Traversal (Phase 2)
Same controls on every device (keyboard / gamepad / touch):
| Do this | How |
|---|---|
| Start climbing | Jump into a wall with **glowing carved handholds** while pushing toward it |
| Climb | Forward = up, back = down, left/right = sideways |
| Climb over the top | Keep climbing up: the ninja pulls up automatically |
| Wall jump | JUMP while climbing (kicks away from the wall) |
| Let go of a wall | Back + JUMP (or climb down to the ground) |
| Grab a ledge | Push toward any ledge while falling past it (or at the top of a jump) |
| Pull up from a ledge | Forward or JUMP |
| Drop from a ledge | Back |
| Shimmy along a ledge | Left / right |

Checkpoint shrines light up (red → teal) as you pass; falling respawns you at the last lit shrine.

Notes:
- Mouse look: click the game window to capture the mouse; Esc releases it. Mouse wheel zooms in top-down mode.
- Touch controls appear automatically on touchscreens. To test them on a PC, run with `-- --touch` (mouse emulates touch).
- Sprint and the future dodge share Shift: dodge will be a *tap*, sprint a *hold*. Revisit in Phase 4.
