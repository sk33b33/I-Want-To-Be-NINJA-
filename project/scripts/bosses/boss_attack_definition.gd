class_name BossAttackDefinition
extends Resource
## One boss attack, fully data-driven (docs/GAME_DESIGN.md "Boss mechanics"): timings, damage,
## selection rules AND behaviour (`kind` + the boss nodes it uses). BossController runs any boss
## from these, so new bosses need data and a scene, not new code.

enum Kind {
	## Warning zone in front, then a hitbox there (antler sweep, shell slam).
	FRONT,
	## Warning strip, then a rush along it at `move_speed`; can stun itself on walls (charge, spin).
	DASH,
	## Glowing circles under/around the player, then eruptions there (root snare, lava burst).
	ERUPTIONS,
	## Ring around the boss, then a radial blast (thorn burst, ember field).
	RADIAL,
}
enum Glow { NONE, BODY, PARTS }

@export var id: StringName
@export var kind: Kind = Kind.FRONT
## Hitbox / warning nodes on the boss scene used by FRONT, DASH and RADIAL attacks.
@export var hitbox_node: NodePath
@export var warning_node: NodePath
## ERUPTIONS: hazard scene (RootSnare script) spawned at the player + these offsets.
@export var eruption_scene: PackedScene
@export var eruption_offsets: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
## Body pitch while telegraphing (positive rears up, negative lowers the head).
@export var telegraph_pitch: float = 0.0
## Rapid pitch wobble while telegraphing (pawing the ground, winding up).
@export var telegraph_wobble: float = 0.0
@export var glow: Glow = Glow.NONE
## Keeps turning toward the player during the telegraph (until the last 0.3 s).
@export var tracks_player: bool = true
## DASH: turn rate (rad/s) toward the player while dashing (0 = straight line).
@export var dash_homing: float = 0.0
## DASH: hitting a wall or pillar stuns the boss for `stun_time`.
@export var stuns_on_wall: bool = false
@export var stun_time: float = 2.5
## Damage element of this attack (for future elemental armor).
@export var element: StringName = &""
## Damage multiplier once this part is broken (e.g. broken antlers -> weaker sweep).
@export var weakened_by_part: StringName = &""
@export var weakened_scale: float = 0.6
@export var display_name: String = ""
## Warning time before the attack becomes dangerous (generous for a prototype).
@export var telegraph_time: float = 1.0
@export var active_time: float = 0.4
## Punish window after the attack.
@export var recovery_time: float = 1.0
@export var damage: float = 20.0
@export var knockback: float = 6.0
## Movement speed during the active part (used by charges).
@export var move_speed: float = 0.0
## The boss picks this attack only when the player is within [min_range, max_range].
@export var min_range: float = 0.0
@export var max_range: float = 6.0
## Relative chance among the valid attacks.
@export var weight: float = 1.0
## Seconds before this attack can be used again.
@export var cooldown: float = 2.0
@export var enraged_only: bool = false
## How to avoid it (shown in docs/tests; kept with the data so it is never forgotten).
@export var counterplay: String = ""
