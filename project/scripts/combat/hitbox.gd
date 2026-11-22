class_name Hitbox
extends Area3D
## An attack's damage volume. While active it hits every overlapping enemy once per activation
## (never its own team). Several hurtboxes of one creature (body + a breakable part) share a
## HealthComponent: they count as ONE hit, landing on the part hurtbox when it is overlapped.
## Lives on physics layer 5 "hitbox", scanning layer 6.

signal hit_landed(hurtbox: Hurtbox, info: DamageInfo)

@export var team: StringName = &"player"

var active: bool = false
var _template: DamageInfo
var _already_hit: Dictionary = {}


func _ready() -> void:
	collision_layer = 16  # layer 5: hitbox
	collision_mask = 32   # layer 6: hurtbox
	monitoring = true
	monitorable = false


func activate(info: DamageInfo) -> void:
	_template = info
	_template.team = team
	_already_hit.clear()
	active = true
	_scan()


func deactivate() -> void:
	active = false


func _physics_process(_delta: float) -> void:
	if active:
		_scan()


func _scan() -> void:
	# Group overlapped hurtboxes by the creature (health) they belong to; prefer part hurtboxes.
	var best: Dictionary = {}
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox.team == team or hurtbox.health == null:
			continue
		var key := hurtbox.health.get_instance_id()
		if _already_hit.has(key):
			continue
		var current := best.get(key) as Hurtbox
		if current == null or (current.part_id == &"" and hurtbox.part_id != &""):
			best[key] = hurtbox
	for key in best:
		_already_hit[key] = true
		var hurtbox := best[key] as Hurtbox
		var info := _template.copy()
		if hurtbox.receive(info):
			hit_landed.emit(hurtbox, info)
