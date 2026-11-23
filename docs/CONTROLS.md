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
| Ember Talisman (fire charm, 4 s cooldown; water with the Mist Charm) | F | RB / R1 | FIRE button |
| Switch camera | V | D-pad down | CAM button |
| Pause (freezes the expedition timer) | Esc | Start / Menu | **II** button (top right) |
| Draw / sheathe blades | R | D-pad ↑ | **BLADE** button (top right) |

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

Checkpoint shrines light up (red → teal) as you pass and heal you the first time; falling respawns you at the last lit shrine.
In the dojo, switch between **Hunt board** and **Forge** with the buttons at the top (mouse, touch, or gamepad focus + A). Forge needs the listed materials; Equip puts owned gear on.
Walk over glowing pickups (Glowcap, Ruin Shard) to gather them; walk up to a lore stone to read it. The arrow under the timer points to the arena.

**Settings** (dojo → Settings tab, and the pause menu; saved between sessions): **Graphics** Auto / Low / Medium / High (Auto = Low on phones, High on PC; applies from the next expedition), **Difficulty** Easy / Normal / Hard (damage taken, beast health, warning time — never the 45:00 countdown), **Master / Music / Sound effects volume** sliders, **Touch button size**, **Screen shake** On/Off, **Bold attack warnings** On/Off (brighter warning zones with thicker rims). The dojo Settings tab also has **Controls**: press a binding (keyboard/mouse or gamepad), then the new key/button; a key that another action uses is swapped with it; **Reset controls to defaults**. Touch buttons keep their layout (CHARM = the talisman). Switching to another app pauses the hunt automatically. It also has **Run benchmark** (about a minute; tours all four jungles and shows frame rates).

Moonfen: mud slows you and you cannot jump while in it; a stream current pushes you sideways; green-rimmed pools are poison; in the fog bank follow the cyan spirit lanterns; reed rafts sink while you stand on them — keep moving.

Stormcrag: on the storm plateau a pale ring appears where you stand — move on (or roll) before the bolt falls, or rest under a rock overhang. On the gale ridge, white chevrons show which way the next gust will blow; cross in the calm. Wet stone is slippery: you speed up and stop slowly.

Sprinting into a climbable wall (sprint + jump at the wall) plays a kick-up onto the wall before the climb.

Light and heavy attacks leave a slash trail behind the blades (heavy: wider and brighter; coloured by a forged blade's element).

Blades: draw / sheathe puts both blades in the left-hip sheath or back in hand. Standing still plays the full animation; on the move you keep running and the blades change place on time; a roll finishes it at once. Attacking with sheathed blades draws them and attacks in one press. Expeditions start with blades drawn.

Notes:
- Mouse look: click the game window to capture the mouse; Esc releases it. Mouse wheel zooms in top-down mode.
- Touch controls appear automatically on touchscreens. To test them on a PC, run with `-- --touch` (mouse emulates touch).
- Shift: a quick tap (under 0.2 s) rolls, holding it sprints. C is a dedicated dodge key.
- Attacks only start on the ground. While locked on, the ninja faces the target and movement strafes around it; rolling with no direction rolls away from the target.
- Touch layout: ATK (big) bottom-right, HVY, JUMP, ROLL, DASH and LOCK around it; CAM and II (pause) top-right.
