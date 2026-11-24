class_name WeaponType
extends Resource
## Phase 13 part 2 ("more weapons"): how a forged weapon PLAYS. The ninja has one set of weapon
## animations (Dual_Weapon_Combo), so weapon types differ by speed, damage per hit, stagger,
## reach, blade shape and one trait — never by new animation. A GearDefinition with no
## weapon_type uses the twin katana (all multipliers 1).
## Balance rule (tested): damage x speed stays within ~±15% of the katana, so the choice is about
## play style and the beast's weakness, not raw power.

@export var id: StringName = &"katana"
@export var display_name: String = "Twin Katana"
## One line on how it plays, shown in the forge.
@export_multiline var play_style: String = ""

@export_group("Feel")
## Swing speed (animation and timing). 1.35 = 35% faster.
@export var speed_multiplier: float = 1.0
## Damage per hit (on top of the gear's blade_damage_multiplier).
@export var damage_multiplier: float = 1.0
@export var stagger_multiplier: float = 1.0
## Hitbox size and forward offset (1 = katana).
@export var reach: float = 1.0
@export var trail_width_multiplier: float = 1.0

@export_group("Trait")
## Extra damage counted towards breaking a beast part (1.6 = parts break 60% sooner).
@export var part_damage_multiplier: float = 1.0
## Poison: damage per second for `poison_seconds` after each hit (refreshes, never stacks).
@export var poison_dps: float = 0.0
@export var poison_seconds: float = 0.0

@export_group("Look")
## ProceduralMeshes builder for each hand's blade (handle at the origin, blade along +Y).
@export var blade_mesh: StringName = &"ninja_blade"
## Slash trail along the blade (metres from the grip), like TrailConfig.base / tip.
@export var trail_base: float = 0.12
@export var trail_tip: float = 0.66


## A copy of `attack` adjusted for this weapon (built once per expedition, never per swing).
func adapt(attack: AttackDefinition) -> AttackDefinition:
	if attack == null:
		return null
	var a := attack.duplicate() as AttackDefinition
	a.speed = attack.speed * speed_multiplier
	a.damage = attack.damage * damage_multiplier
	a.stagger = attack.stagger * stagger_multiplier
	a.trail_width = attack.trail_width * trail_width_multiplier
	return a


## Readable lines for the forge, e.g. "Fast: swings 35% quicker".
func stat_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if speed_multiplier > 1.0:
		lines.append("Swings %d%% faster" % int(round((speed_multiplier - 1.0) * 100.0)))
	elif speed_multiplier < 1.0:
		lines.append("Swings %d%% slower" % int(round((1.0 - speed_multiplier) * 100.0)))
	if damage_multiplier != 1.0:
		lines.append("Damage per hit %+d%%" % int(round((damage_multiplier - 1.0) * 100.0)))
	if stagger_multiplier != 1.0:
		lines.append("Stagger %+d%%" % int(round((stagger_multiplier - 1.0) * 100.0)))
	if reach > 1.0:
		lines.append("Longer reach")
	elif reach < 1.0:
		lines.append("Shorter reach")
	if part_damage_multiplier != 1.0:
		lines.append("Breaks parts %d%% sooner" % int(round((part_damage_multiplier - 1.0) * 100.0)))
	if poison_dps > 0.0:
		lines.append("Poisons: %d damage over %ds" % [int(poison_dps * poison_seconds), int(poison_seconds)])
	return lines


## Damage over time relative to the katana (speed x damage), for balance checks.
func dps_ratio() -> float:
	return speed_multiplier * damage_multiplier
