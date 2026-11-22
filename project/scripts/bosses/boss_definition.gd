class_name BossDefinition
extends Resource
## Everything data-driven about a boss: stats, element profile, attacks, parts, rewards.

@export var id: StringName
@export var display_name: String = ""
@export var max_health: float = 900.0
## Poise: accumulated stagger damage that interrupts the boss (not during an active attack).
@export var poise: float = 120.0
@export var stagger_time: float = 1.4
@export var elements: ElementProfile
@export var attacks: Array[BossAttackDefinition] = []
@export var parts: Array[BossPartDefinition] = []
## Granted on victory.
@export var victory_rewards: Array[ItemDefinition] = []

@export_group("Movement")
@export var walk_speed: float = 3.0
@export var turn_sharpness: float = 4.0
## Preferred distance while stalking between attacks.
@export var stalk_distance: float = 5.0
## Pause between attacks (seconds), shortened when enraged.
@export var attack_interval: float = 1.2
@export var arena_radius: float = 17.0

@export_group("Enrage")
## Health fraction at which the boss enrages.
@export var enrage_at: float = 0.5
## Telegraphs and pauses are multiplied by this when enraged (lower = faster).
@export var enrage_tempo: float = 0.8

@export_group("Presentation")
## Body mesh (spine glow + hit flash). Part meshes come from BossPartDefinition.intact_node.
@export var body_mesh_node: NodePath = ^"Visual/Body"
## Pitch while recovering / staggered (negative lowers the head so head parts can be struck).
@export var head_down_pitch: float = -0.6
## Lock-on point relative to the boss (forward is -Z).
@export var lock_offset: Vector3 = Vector3(0, 2.6, -1.8)
@export var intro_time: float = 2.2
@export var death_time: float = 3.0


func get_attack(attack_id: StringName) -> BossAttackDefinition:
	for a in attacks:
		if a.id == attack_id:
			return a
	return null


func get_part(part_id: StringName) -> BossPartDefinition:
	for p in parts:
		if p.id == part_id:
			return p
	return null
