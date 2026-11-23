class_name PlayerCombatConfig
extends Resource
## Player combat tuning (docs/PHASES.md Phase 4). Attacks are separate AttackDefinition resources.

@export_group("Attacks")
## Light combo in order (chained by pressing light again during the cancel window).
@export var light_combo: Array[AttackDefinition] = []
@export var heavy: AttackDefinition
## Brief freeze on a landed hit so impacts read (seconds).
@export var hit_stop: float = 0.06
## How long an attack/dodge press is remembered while busy.
@export var input_buffer: float = 0.3

@export_group("Ember Talisman (fire skill)")
@export var skill: AttackDefinition
@export var skill_cooldown: float = 4.0

@export_group("Health")
@export var max_health: float = 100.0
## Seconds of hit-stun after being hurt.
@export var hurt_time: float = 0.35
## Seconds on the ground after death before respawning at the last checkpoint.
@export var respawn_delay: float = 2.5

@export_group("Dodge")
@export var dodge_speed: float = 11.0
@export var dodge_time: float = 0.42
## Invulnerability window, seconds from dodge start.
@export var iframe_start: float = 0.03
@export var iframe_end: float = 0.32
@export var dodge_cooldown: float = 0.15
## Shift presses shorter than this count as a dodge tap on keyboard (holding still sprints).
@export var keyboard_tap_time: float = 0.2

@export_group("Blades: draw / sheathe")
## Expeditions start with the blades in hand (false) or in their hip sheath (true).
@export var start_sheathed: bool = false
## Draw_Sword / Sheath_Sword timing (seconds). The blades change place (hip <-> hands) at the
## *_swap_at moment, which matches the hand reaching the left-hip sheath in the clip.
@export var draw_time: float = 0.8
@export var draw_swap_at: float = 0.05
@export var sheathe_time: float = 1.2
@export var sheathe_swap_at: float = 0.85

@export_group("Lock-on")
@export var lock_range: float = 18.0
## Locks break when the target gets this much farther than lock_range.
@export var lock_break_factor: float = 1.4
