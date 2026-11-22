class_name Hitbox
extends Area3D
## An attack's damage volume. While active it hits every overlapping enemy Hurtbox once per
## activation (never its own team). Lives on physics layer 5 "hitbox", scanning layer 6.

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
	area_entered.connect(_try_hit)


func activate(info: DamageInfo) -> void:
	_template = info
	_template.team = team
	_already_hit.clear()
	active = true
	for area in get_overlapping_areas():
		_try_hit(area)


func deactivate() -> void:
	active = false


func _physics_process(_delta: float) -> void:
	if active:
		for area in get_overlapping_areas():
			_try_hit(area)


func _try_hit(area: Area3D) -> void:
	if not active or not area is Hurtbox:
		return
	var hurtbox := area as Hurtbox
	if hurtbox.team == team:
		return
	var key := hurtbox.get_instance_id()
	if _already_hit.has(key):
		return
	_already_hit[key] = true
	var info := _template.copy()
	if hurtbox.receive(info):
		hit_landed.emit(hurtbox, info)
