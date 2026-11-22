# Controls (prototype defaults)

Implemented in Phase 1: move, camera, jump, sprint (dash-run), switch camera, pause (frees the mouse).
Implemented in Phase 2: climbing, ledge grab, mantle, wall jump — all automatic, no extra buttons (see "Traversal" below).
Implemented in Phase 4: light attack (3-hit combo), heavy attack, dodge roll, lock-on.
Implemented in Phase 5: Ember Talisman (fire skill).
Not yet implemented: interact.

| Action | Keyboard | Controller | Phone (touch) |
|---|---|---|---|
| Move | WASD | Left stick | Left side: floating joystick |
| Camera | Mouse | Right stick | Right side: drag |
| Jump | Space | A / Cross | JUMP button |
| Sprint (dash-run, hold) | Shift (hold) | Left-stick click | DASH button |
| Sprint-jump (front flip) | Shift + Space | L3 + A | DASH + JUMP |
| Dodge roll (brief invulnerability) | Shift (quick tap) or C | B / Circle | ROLL button |
| Light attack (press again for a 3-hit combo) | Left mouse | X / Square | ATK button |
| Heavy attack (breaks enemy poise) | Right mouse | Y / Triangle | HVY button |
| Lock-on (press again to release) | Q or middle mouse | Right-stick click | LOCK button |
| Interact | E | X / Square (context-sensitive) | — (later) |
| Ember Talisman (fire charm, 4 s cooldown) | F | RB / R1 | FIRE button |
| Switch camera | V | D-pad down | CAM button |
| Pause (freezes the expedition timer) | Esc | Start / Menu | **II** button (top right) |

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
- Shift: a quick tap (under 0.2 s) rolls, holding it sprints. C is a dedicated dodge key.
- Attacks only start on the ground. While locked on, the ninja faces the target and movement strafes around it; rolling with no direction rolls away from the target.
- Touch layout: ATK (big) bottom-right, HVY, JUMP, ROLL, DASH and LOCK around it; CAM and II (pause) top-right.
