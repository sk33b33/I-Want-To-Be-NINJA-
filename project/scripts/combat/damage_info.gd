class_name DamageInfo
extends RefCounted
## One hit's worth of damage, passed from a Hitbox to a Hurtbox (docs/ARCHITECTURE.md damage events).

var amount: float = 0.0
## Poise damage: a hit staggers the target when it reaches the target's poise.
var stagger: float = 0.0
## Knockback speed (m/s) applied away from the attacker.
var knockback: float = 0.0
var element: StringName = &""
var team: StringName = &""
var source: Node3D
var hit_position: Vector3 = Vector3.ZERO
## Name of the attack that caused this hit (for feedback and debugging).
var attack_name: StringName = &""
## Weapon traits (WeaponType, Phase 13): extra damage towards breaking parts, and poison applied
## by the target's Hurtbox after the hit lands.
var part_multiplier: float = 1.0
var poison_dps: float = 0.0
var poison_seconds: float = 0.0


func copy() -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = amount
	d.stagger = stagger
	d.knockback = knockback
	d.element = element
	d.team = team
	d.source = source
	d.part_multiplier = part_multiplier
	d.poison_dps = poison_dps
	d.poison_seconds = poison_seconds
	d.hit_position = hit_position
	d.attack_name = attack_name
	return d


## Horizontal direction from the attacker to `target_pos` (for knockback).
func push_direction(target_pos: Vector3) -> Vector3:
	if source == null:
		return Vector3.ZERO
	var d := target_pos - source.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.001 else Vector3.ZERO
